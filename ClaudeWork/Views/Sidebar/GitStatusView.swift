import SwiftUI

/// 프로젝트의 Git 상태를 시각적으로 보여주는 뷰.
struct GitStatusView: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var gitStatus: GitStatusInfo = .loading
    @State private var refreshTask: Task<Void, Never>?
    @State private var localBranches: [String] = []
    @State private var remoteBranches: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch gitStatus {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("확인 중...")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Spacer()
                }

            case .notARepo:
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Text("Git 프로젝트가 아님")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Spacer()
                }

            case .clean(let branch):
                // 첫 줄: 브랜치 버튼 + 새로고침
                HStack(spacing: 8) {
                    branchMenu(branch)
                    Spacer()
                    refreshButton
                }
                // 둘째 줄: 상태
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ClaudeTheme.statusSuccess)
                    Text("변경 없음")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }

            case .dirty(let branch, let changes):
                // 첫 줄: 브랜치 버튼 + 새로고침
                HStack(spacing: 8) {
                    branchMenu(branch)
                    Spacer()
                    refreshButton
                }
                // 둘째 줄: 변경 상태 + 뱃지
                HStack(spacing: 6) {
                    Circle()
                        .fill(ClaudeTheme.accent)
                        .frame(width: 6, height: 6)
                    Text("\(changes.total)개 변경")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeTheme.accent)

                    if changes.modified > 0 {
                        badge("수정 \(changes.modified)", color: .blue)
                    }
                    if changes.added > 0 {
                        badge("추가 \(changes.added)", color: ClaudeTheme.statusSuccess)
                    }
                    if changes.deleted > 0 {
                        badge("삭제 \(changes.deleted)", color: ClaudeTheme.statusError)
                    }
                }

            case .error:
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Text("상태 확인 실패")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Spacer()
                    refreshButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ClaudeTheme.surfaceSecondary.opacity(0.5))
        .onAppear { refresh() }
        .onChange(of: projectPath) { _, _ in refresh() }
        .onChange(of: appState.isStreaming) { old, new in
            if old && !new { refresh() }
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button {
            refresh()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10))
                .foregroundStyle(ClaudeTheme.textTertiary)
        }
        .buttonStyle(.borderless)
        .help("새로고침")
    }

    // MARK: - Branch Menu

    private func branchMenu(_ currentBranch: String) -> some View {
        Menu {
            Section("로컬") {
                ForEach(localBranches, id: \.self) { branch in
                    Button {
                        Task {
                            let success = await gitCheckout(branch: branch, at: projectPath)
                            if success { refresh(); loadBranches() }
                        }
                    } label: {
                        HStack {
                            Text(branch)
                            if branch == currentBranch {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(branch == currentBranch)
                }
                if localBranches.isEmpty {
                    Text("로컬 브랜치 없음")
                }
            }

            Section("리모트 (origin)") {
                ForEach(remoteBranches, id: \.self) { branch in
                    Button {
                        // 리모트 브랜치 체크아웃 시 로컬 트래킹 브랜치 생성
                        Task {
                            let success = await gitCheckout(branch: branch, at: projectPath)
                            if success { refresh(); loadBranches() }
                        }
                    } label: {
                        Text(branch)
                    }
                }
                if remoteBranches.isEmpty {
                    Text("리모트 브랜치 없음")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                Text(currentBranch)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(ClaudeTheme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(ClaudeTheme.surfacePrimary.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("브랜치 변경")
        .onAppear { loadBranches() }
        .onChange(of: projectPath) { _, _ in loadBranches() }
    }

    // MARK: - Role & Branch Loading

    private var currentRole: ProjectRole? {
        let setup = SetupService()
        return setup.getProjectRole(at: projectPath)
    }

    private func loadBranches() {
        Task {
            let result = await fetchGitBranches(at: projectPath)
            let role = currentRole
            guard let prefix = role?.branchPrefix else {
                localBranches = result.local
                remoteBranches = result.remote
                return
            }
            let current = currentBranchName
            let allowed: (String) -> Bool = { branch in
                branch.hasPrefix(prefix)
                || branch == "main"
                || branch == "master"
                || branch == "develop"
                || branch == "qa"
                || branch == current
            }
            localBranches = result.local.filter(allowed)
            remoteBranches = result.remote.filter(allowed)
        }
    }

    private var currentBranchName: String? {
        switch gitStatus {
        case .clean(let branch): branch
        case .dirty(let branch, _): branch
        default: nil
        }
    }

    // MARK: - Badge

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Refresh

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            gitStatus = .loading
            gitStatus = await fetchGitStatus(at: projectPath)
        }
    }
}

// MARK: - Git Status Model

enum GitStatusInfo: Sendable {
    case loading
    case notARepo
    case clean(branch: String)
    case dirty(branch: String, changes: ChangeCount)
    case error

    struct ChangeCount: Sendable {
        let modified: Int
        let added: Int
        let deleted: Int
        var total: Int { modified + added + deleted }
    }
}

// MARK: - Git Status Fetcher

private func fetchGitStatus(at path: String) async -> GitStatusInfo {
    guard let branchResult = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: path),
          !branchResult.isEmpty else {
        return .notARepo
    }

    let branch = branchResult.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let statusResult = await runGit(["status", "--porcelain"], at: path) else {
        return .error
    }

    if statusResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .clean(branch: branch)
    }

    let lines = statusResult.components(separatedBy: "\n").filter { !$0.isEmpty }
    var modified = 0
    var added = 0
    var deleted = 0

    for line in lines {
        guard line.count >= 2 else { continue }
        let index = line.index(line.startIndex, offsetBy: 1)
        let statusChar = line[index]
        switch statusChar {
        case "M": modified += 1
        case "A", "?": added += 1
        case "D": deleted += 1
        default: modified += 1
        }
    }

    return .dirty(
        branch: branch,
        changes: .init(modified: modified, added: added, deleted: deleted)
    )
}

// MARK: - Git Branch List

struct BranchList {
    var local: [String] = []
    var remote: [String] = []
}

private func fetchGitBranches(at path: String) async -> BranchList {
    guard let result = await runGit(["branch", "-a", "--no-color"], at: path) else {
        return BranchList()
    }

    var local: [String] = []
    var remote: [String] = []
    var localSet = Set<String>()

    for line in result.components(separatedBy: "\n") {
        var name = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("* ") { name = String(name.dropFirst(2)) }
        if name.isEmpty { continue }
        if name.contains("->") { continue }

        if name.hasPrefix("remotes/origin/") {
            let shortName = String(name.dropFirst("remotes/origin/".count))
            remote.append(shortName)
        } else {
            local.append(name)
            localSet.insert(name)
        }
    }

    // 리모트에서 이미 로컬에 있는 브랜치 제외
    remote = remote.filter { !localSet.contains($0) }

    return BranchList(local: local.sorted(), remote: remote.sorted())
}

// MARK: - Git Checkout

private func gitCheckout(branch: String, at path: String) async -> Bool {
    guard let _ = await runGit(["checkout", branch], at: path) else {
        return false
    }
    return true
}

// MARK: - Git Runner

private func runGit(_ args: [String], at path: String) async -> String? {
    await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.environment = ProcessInfo.processInfo.environment.merging([
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_PAGER": "",
            "PAGER": "",
        ]) { _, new in new }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil as String?
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }.value
}

#Preview {
    VStack(spacing: 0) {
        GitStatusView(projectPath: "/Users/jmlee/workspace/ClaudeWork")
    }
    .frame(width: 400)
}
