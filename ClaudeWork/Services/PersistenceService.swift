import Foundation
import os

actor PersistenceService {

    private let baseURL: URL
    private let logger = Logger(subsystem: "com.claudework", category: "PersistenceService")

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.baseURL = appSupport.appendingPathComponent("ClaudeWork")
    }

    // MARK: - Projects

    func saveProjects(_ projects: [Project]) throws {
        let url = baseURL.appendingPathComponent("projects.json")
        try encode(projects, to: url)
    }

    func loadProjects() -> [Project] {
        let url = baseURL.appendingPathComponent("projects.json")
        return decode([Project].self, from: url) ?? []
    }

    // MARK: - Sessions

    func saveSession(_ session: ChatSession) throws {
        let dir = baseURL
            .appendingPathComponent("sessions")
            .appendingPathComponent(session.projectId.uuidString)
        try ensureDirectory(dir)

        let url = dir.appendingPathComponent("\(session.id).json")
        try encode(session, to: url)
    }

    func loadSessions(for projectId: UUID) -> [ChatSession] {
        let dir = baseURL
            .appendingPathComponent("sessions")
            .appendingPathComponent(projectId.uuidString)

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { decode(ChatSession.self, from: $0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadSession(projectId: UUID, sessionId: String) -> ChatSession? {
        let url = baseURL
            .appendingPathComponent("sessions")
            .appendingPathComponent(projectId.uuidString)
            .appendingPathComponent("\(sessionId).json")
        return decode(ChatSession.self, from: url)
    }

    // MARK: - GitHub User Cache

    func saveGitHubUser(_ user: GitHubUser) throws {
        let url = baseURL.appendingPathComponent("github_user.json")
        try encode(user, to: url)
    }

    func loadGitHubUser() -> GitHubUser? {
        let url = baseURL.appendingPathComponent("github_user.json")
        return decode(GitHubUser.self, from: url)
    }

    // MARK: - Private Helpers

    private func ensureDirectory(_ url: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)

        logger.debug("Saved \(url.lastPathComponent, privacy: .public)")
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            logger.error(
                "Failed to decode \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            // 손상된 파일을 백업으로 이동하여 데이터 보존
            let backupURL = url.deletingPathExtension()
                .appendingPathExtension("corrupted-\(Int(Date().timeIntervalSince1970)).json")
            try? fm.moveItem(at: url, to: backupURL)
            logger.warning("Moved corrupted file to \(backupURL.lastPathComponent, privacy: .public)")
            return nil
        }
    }
}
