import Foundation
import os

// MARK: - Project Role

enum ProjectRole: String, CaseIterable, Sendable {
    case dev
    case po
    case design

    var title: String {
        switch self {
        case .dev: "Developer"
        case .po: "Product Owner"
        case .design: "Designer"
        }
    }

    var icon: String {
        switch self {
        case .dev: "chevron.left.forwardslash.chevron.right"
        case .po: "chart.bar.doc.horizontal"
        case .design: "paintbrush"
        }
    }

    var description: String {
        switch self {
        case .dev: "개발 작업을 수행합니다"
        case .po: "제품 기획과 관리를 수행합니다"
        case .design: "디자인 작업을 수행합니다"
        }
    }

    /// 역할별 브랜치 접두사. dev는 nil(모든 브랜치 접근 가능).
    var branchPrefix: String? {
        switch self {
        case .dev: nil
        case .po: "po/"
        case .design: "design/"
        }
    }
}

/// Manages global tool installation checks and execution.
/// Checks for: gstack, claude commands (start/submit/cancel), git-workflow skill.
actor SetupService {

    private let logger = Logger(subsystem: "com.claudework", category: "SetupService")

    // MARK: - Tool Status

    struct ToolStatus: Sendable {
        var gstackInstalled: Bool
        var superpowersInstalled: Bool
        var commandsInstalled: Bool
        var gitWorkflowInstalled: Bool

        var allInstalled: Bool {
            gstackInstalled && superpowersInstalled && commandsInstalled && gitWorkflowInstalled
        }
    }

    // MARK: - Check All Tools

    func checkAllTools() async -> ToolStatus {
        async let gstack = isGstackInstalled()
        async let superpowers = isSuperpowersInstalled()
        async let commands = areCommandsInstalled()
        async let gitWorkflow = isGitWorkflowInstalled()

        return ToolStatus(
            gstackInstalled: await gstack,
            superpowersInstalled: await superpowers,
            commandsInstalled: await commands,
            gitWorkflowInstalled: await gitWorkflow
        )
    }

    // MARK: - Install All Missing Tools

    func installMissing(status: ToolStatus) async throws -> ToolStatus {
        var updated = status

        // Run all installs concurrently
        try await withThrowingTaskGroup(of: (String, Bool).self) { group in
            if !status.gstackInstalled {
                group.addTask {
                    try await self.installGstack()
                    return ("gstack", true)
                }
            }
            if !status.superpowersInstalled {
                group.addTask {
                    try await self.installSuperpowers()
                    return ("superpowers", true)
                }
            }
            if !status.commandsInstalled {
                group.addTask {
                    try await self.installCommands()
                    return ("commands", true)
                }
            }
            if !status.gitWorkflowInstalled {
                group.addTask {
                    try await self.installGitWorkflow()
                    return ("gitWorkflow", true)
                }
            }

            for try await (tool, _) in group {
                switch tool {
                case "gstack": updated.gstackInstalled = true
                case "superpowers": updated.superpowersInstalled = true
                case "commands": updated.commandsInstalled = true
                case "gitWorkflow": updated.gitWorkflowInstalled = true
                default: break
                }
            }
        }

        return updated
    }

    // MARK: - gstack

    private func isGstackInstalled() -> Bool {
        FileManager.default.fileExists(atPath: claudeHomePath("skills/gstack/SKILL.md"))
    }

    private func installGstack() async throws {
        let targetDir = claudeHomePath("skills/gstack")
        let fm = FileManager.default

        if fm.fileExists(atPath: targetDir) {
            try fm.removeItem(atPath: targetDir)
        }

        logger.info("Installing gstack via git clone + setup...")
        try await runShell("git clone https://github.com/garrytan/gstack.git \"\(targetDir)\" && cd \"\(targetDir)\" && ./setup")
    }

    // MARK: - Superpowers

    private func isSuperpowersInstalled() -> Bool {
        let jsonPath = claudeHomePath("plugins/installed_plugins.json")
        guard let data = FileManager.default.contents(atPath: jsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else {
            return false
        }
        return plugins["superpowers@claude-plugins-official"] != nil
    }

    private func installSuperpowers() async throws {
        logger.info("Installing superpowers via claude plugin...")
        try await runShell("claude plugin install superpowers@claude-plugins-official")
    }

    // MARK: - Commands (start, submit, cancel)

    private let requiredCommands = ["start.md", "submit.md", "cancel.md"]

    private func areCommandsInstalled() -> Bool {
        let claudeCommandsDir = claudeHomePath("commands")
        let fm = FileManager.default

        return requiredCommands.allSatisfy { cmd in
            fm.fileExists(atPath: (claudeCommandsDir as NSString).appendingPathComponent(cmd))
        }
    }

    private func installCommands() throws {
        let sourceDir = bundledSourcePath("commands")
        let targetDir = claudeHomePath("commands")
        let fm = FileManager.default

        if !fm.fileExists(atPath: targetDir) {
            try fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        }

        for cmd in requiredCommands {
            let src = (sourceDir as NSString).appendingPathComponent(cmd)
            let dst = (targetDir as NSString).appendingPathComponent(cmd)

            guard fm.fileExists(atPath: src) else {
                logger.warning("Source command not found: \(src)")
                continue
            }

            if fm.fileExists(atPath: dst) {
                try fm.removeItem(atPath: dst)
            }
            try fm.copyItem(atPath: src, toPath: dst)
            logger.info("Installed command: \(cmd)")
        }
    }

    // MARK: - Git Workflow Skill

    private func isGitWorkflowInstalled() -> Bool {
        FileManager.default.fileExists(atPath: claudeHomePath("skills/git-workflow/SKILL.md"))
    }

    private func installGitWorkflow() throws {
        let sourceDir = bundledSourcePath("git-workflow")
        let targetDir = claudeHomePath("skills/git-workflow")
        let fm = FileManager.default

        let skillsDir = claudeHomePath("skills")
        if !fm.fileExists(atPath: skillsDir) {
            try fm.createDirectory(atPath: skillsDir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: targetDir) {
            try fm.removeItem(atPath: targetDir)
        }

        try fm.copyItem(atPath: sourceDir, toPath: targetDir)
        logger.info("Installed git-workflow skill")
    }

    // MARK: - Project Role

    nonisolated func projectHasRole(at projectPath: String) -> Bool {
        let rolePath = (projectPath as NSString).appendingPathComponent(".claude/role")
        return FileManager.default.fileExists(atPath: rolePath)
    }

    nonisolated func getProjectRole(at projectPath: String) -> ProjectRole? {
        let rolePath = (projectPath as NSString).appendingPathComponent(".claude/role")
        guard let raw = try? String(contentsOfFile: rolePath, encoding: .utf8) else { return nil }
        return ProjectRole(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    nonisolated func setProjectRole(at projectPath: String, role: ProjectRole) throws {
        let claudeDir = (projectPath as NSString).appendingPathComponent(".claude")
        let rolePath = (claudeDir as NSString).appendingPathComponent("role")
        let fm = FileManager.default

        if !fm.fileExists(atPath: claudeDir) {
            try fm.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }

        try role.rawValue.write(toFile: rolePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func claudeHomePath(_ subpath: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/\(subpath)"
    }

    private func bundledSourcePath(_ subpath: String) -> String {
        let bundlePath = Bundle.main.resourcePath ?? ""
        let resourcePath = (bundlePath as NSString).appendingPathComponent("claude source/\(subpath)")

        if FileManager.default.fileExists(atPath: resourcePath) {
            return resourcePath
        }

        let devPath = (FileManager.default.currentDirectoryPath as NSString)
            .appendingPathComponent("claude source/\(subpath)")
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        let projectPath = ProcessInfo.processInfo.environment["PROJECT_DIR"]
            ?? findProjectDir()
        return "\(projectPath)/claude source/\(subpath)"
    }

    private func findProjectDir() -> String {
        let execURL = Bundle.main.executableURL ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        var dir = execURL.deletingLastPathComponent()

        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("claude source").path
            if FileManager.default.fileExists(atPath: candidate) {
                return dir.path
            }
            dir = dir.deletingLastPathComponent()
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("workspace/ClaudeWork").path
    }

    @discardableResult
    private func runShell(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]
            process.standardOutput = pipe
            process.standardError = pipe

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: SetupError.commandFailed(command, output))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Errors

enum SetupError: LocalizedError {
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let output):
            return "Command failed: \(cmd)\n\(output)"
        }
    }
}
