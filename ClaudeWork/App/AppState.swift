import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class AppState {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.claudework", category: "AppState")

    // MARK: - Projects

    var projects: [Project] = []
    var selectedProject: Project?

    // MARK: - Chat

    var messages: [ChatMessage] = []
    var isStreaming = false
    var isThinking = false
    var inputText = ""

    // MARK: - Start Mode

    var isStartMode = false

    // MARK: - Model

    static let availableModels = [
        "claude-opus-4-6",
        "claude-sonnet-4-6",
        "claude-haiku-4-5",
    ]
    var selectedModel: String = "claude-opus-4-6"

    // MARK: - Sessions

    var sessions: [ChatSession] = []
    var currentSessionId: String?

    // MARK: - Tool Approval Queue

    var pendingPermissions: [PermissionRequest] = []

    // MARK: - GitHub

    var isLoggedIn = false
    var gitHubUser: GitHubUser?
    var repos: [GitHubRepo] = []

    // MARK: - CLI Version

    var claudeVersion: String?

    // MARK: - Onboarding

    var claudeInstalled = false
    var onboardingCompleted = false

    // MARK: - Error State

    var errorMessage: String?
    var showError = false

    // MARK: - Services

    let claude = ClaudeService()
    let github = GitHubService()
    let permission = PermissionServer()
    let persistence = PersistenceService()

    // MARK: - Private State

    /// Buffer for accumulating text deltas before flushing to the UI.
    private var textDeltaBuffer = ""
    /// Task that periodically flushes the text delta buffer.
    private var flushTask: Task<Void, Never>?
    /// Long-running task that listens for permission requests.
    private var permissionListenerTask: Task<Void, Never>?
    /// The currently running stream task (for cancellation).
    private var streamTask: Task<Void, Never>?

    // MARK: - Initialization

    func initialize() async {
        // Check if claude binary exists and fetch version
        let binary = await claude.findClaudeBinary()
        claudeInstalled = binary != nil

        if binary != nil {
            do {
                claudeVersion = try await claude.checkVersion()
            } catch {
                logger.warning("Failed to fetch Claude CLI version: \(error.localizedDescription)")
            }
        }

        // Load projects from persistence
        projects = await persistence.loadProjects()

        // Load GitHub user from persistence
        if let cachedUser = await persistence.loadGitHubUser() {
            gitHubUser = cachedUser
            isLoggedIn = true
            // Also load the token into the service
            _ = await github.loadToken()
        }

        // Check onboarding status — if CLI is installed, allow skipping onboarding
        if claudeInstalled {
            onboardingCompleted = true
        }

        // Start permission server
        do {
            try await permission.start()
        } catch {
            logger.error("Failed to start permission server: \(error.localizedDescription)")
            handleError(error)
        }

        // Start listening for permission requests
        permissionListenerTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.permission.permissionRequests
            for await request in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.pendingPermissions.append(request)
                }
            }
        }
    }

    // MARK: - Send Message

    func send() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        inputText = ""
        await sendPrompt(prompt)
    }

    // MARK: - Send Slash Command

    func sendSlashCommand(_ command: String) async {
        await sendPrompt(command)
    }

    // MARK: - Shared Send Logic

    private func sendPrompt(_ prompt: String) async {
        guard let project = selectedProject else {
            handleError(AppError.noProjectSelected)
            return
        }

        messages.append(ChatMessage(role: .user, content: prompt))
        isStreaming = true

        var hookSettingsPath: String?
        do {
            hookSettingsPath = try await permission.writeHookSettingsFile()
        } catch {
            logger.error("Failed to write hook settings: \(error.localizedDescription)")
        }

        await permission.refreshRunToken()

        streamTask = Task { [weak self] in
            guard let self else { return }
            await self.processStream(
                prompt: prompt,
                cwd: project.path,
                sessionId: self.currentSessionId,
                model: self.selectedModel,
                hookSettingsPath: hookSettingsPath
            )
        }
    }

    // MARK: - Stream Processing

    private func processStream(
        prompt: String,
        cwd: String,
        sessionId: String?,
        model: String?,
        hookSettingsPath: String?
    ) async {
        let stream = await claude.send(
            prompt: prompt,
            cwd: cwd,
            sessionId: sessionId,
            model: model,
            hookSettingsPath: hookSettingsPath
        )

        // Start the 50ms text delta flush timer
        startFlushTimer()

        do {
            for await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                case .system(let systemEvent):
                    // Save session ID from init event
                    if let sid = systemEvent.sessionId {
                        await MainActor.run {
                            self.currentSessionId = sid
                        }
                    }

                case .assistant(let assistantMessage):
                    // Build the complete assistant message from the full event
                    var newMessage = ChatMessage(role: .assistant, isStreaming: true)

                    for block in assistantMessage.content {
                        switch block {
                        case .text(let text):
                            newMessage.content += text
                        case .toolUse(let id, let name, let input):
                            let toolCall = ToolCall(id: id, name: name, input: input)
                            newMessage.toolCalls.append(toolCall)
                        case .thinking:
                            break
                        }
                    }

                    await MainActor.run {
                        // Discard any buffered deltas — the full event has the complete content
                        self.textDeltaBuffer = ""

                        // If the last message is a streaming assistant message,
                        // replace it instead of appending a duplicate
                        if let lastIndex = self.messages.indices.last,
                           self.messages[lastIndex].role == .assistant,
                           self.messages[lastIndex].isStreaming {
                            self.messages[lastIndex] = newMessage
                        } else {
                            self.messages.append(newMessage)
                        }
                    }

                case .user(let userMessage):
                    // Tool result — update the matching ToolCall in the last assistant message
                    await MainActor.run {
                        self.flushTextDeltaBuffer()
                        guard let lastIndex = self.messages.indices.last,
                              self.messages[lastIndex].role == .assistant else { return }

                        if let toolIndex = self.messages[lastIndex].toolCalls.firstIndex(
                            where: { $0.id == userMessage.toolUseId }
                        ) {
                            self.messages[lastIndex].toolCalls[toolIndex].result = userMessage.content
                            self.messages[lastIndex].toolCalls[toolIndex].isError = userMessage.isError
                        }
                    }

                case .result(let resultEvent):
                    await MainActor.run {
                        self.flushTextDeltaBuffer()
                        self.stopFlushTimer()
                        self.isStreaming = false
                        self.isThinking = false

                        // Mark the last assistant message as no longer streaming
                        if let lastIndex = self.messages.indices.last,
                           self.messages[lastIndex].role == .assistant {
                            self.messages[lastIndex].isStreaming = false
                        }

                        // Save session ID from result
                        self.currentSessionId = resultEvent.sessionId

                        if resultEvent.isError {
                            self.errorMessage = "Claude returned an error."
                            self.showError = true
                        }
                    }

                    // Save session
                    await saveCurrentSession()

                case .rateLimitEvent(let info):
                    await MainActor.run {
                        if let retry = info.retrySec {
                            self.errorMessage = "Rate limited. Retrying in \(Int(retry))s..."
                            self.showError = true
                        }
                    }

                case .unknown(let raw):
                    // Handle partial/streaming events from --include-partial-messages
                    // These arrive as raw JSON; attempt to extract text deltas
                    await handlePartialEvent(raw)
                }
            }

            // Stream ended — ensure final state is clean
            await MainActor.run {
                self.flushTextDeltaBuffer()
                self.stopFlushTimer()
                if self.isStreaming {
                    self.isStreaming = false
                        self.isThinking = false
                    // Mark last message as done streaming
                    if let lastIndex = self.messages.indices.last,
                       self.messages[lastIndex].role == .assistant {
                        self.messages[lastIndex].isStreaming = false
                    }
                }
            }

        } // end for-await — no explicit catch needed; AsyncStream doesn't throw
    }

    /// Handle unknown/partial events that may contain streaming text deltas.
    private func handlePartialEvent(_ raw: String) async {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // stream_event wraps the actual event under "event" key
        let event: [String: Any]
        if let type = json["type"] as? String, type == "stream_event",
           let nested = json["event"] as? [String: Any] {
            event = nested
        } else {
            event = json
        }

        guard let eventType = event["type"] as? String else { return }

        if eventType == "content_block_delta" {
            if let delta = event["delta"] as? [String: Any] {
                if let text = delta["text"] as? String {
                    await MainActor.run {
                        self.isThinking = false
                        self.textDeltaBuffer += text
                    }
                } else if delta["type"] as? String == "thinking_delta" {
                    await MainActor.run {
                        self.isThinking = true
                    }
                }
            }
        } else if eventType == "content_block_start" {
            if let contentBlock = event["content_block"] as? [String: Any],
               let blockType = contentBlock["type"] as? String {
                if blockType == "thinking" {
                    await MainActor.run {
                        self.isThinking = true
                    }
                } else if blockType == "text" {
                    await MainActor.run {
                        self.isThinking = false
                    }
                } else if blockType == "tool_use",
                          let id = contentBlock["id"] as? String,
                          let name = contentBlock["name"] as? String {
                    await MainActor.run {
                        self.isThinking = false
                        self.flushTextDeltaBuffer()
                        guard let lastIndex = self.messages.indices.last,
                              self.messages[lastIndex].role == .assistant else { return }
                        let toolCall = ToolCall(id: id, name: name)
                        self.messages[lastIndex].toolCalls.append(toolCall)
                    }
                }
            }
        }
    }

    // MARK: - Text Delta Throttle (50ms)

    private func startFlushTimer() {
        stopFlushTimer()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.flushTextDeltaBuffer()
                }
            }
        }
    }

    private func stopFlushTimer() {
        flushTask?.cancel()
        flushTask = nil
    }

    /// Flush accumulated text deltas to the last assistant message.
    /// Must be called on MainActor.
    private func flushTextDeltaBuffer() {
        guard !textDeltaBuffer.isEmpty else { return }

        let text = textDeltaBuffer
        textDeltaBuffer = ""

        // Append to the last assistant message, or create one if needed
        if let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
            messages[lastIndex].content += text
        } else {
            // No assistant message yet — create one
            let newMessage = ChatMessage(role: .assistant, content: text, isStreaming: true)
            messages.append(newMessage)
        }
    }

    // MARK: - Permission Response

    func respondToPermission(_ request: PermissionRequest, decision: PermissionDecision) async {
        await permission.respond(toolUseId: request.id, decision: decision)
        pendingPermissions.removeAll { $0.id == request.id }
    }

    // MARK: - Project Management

    func addProject(name: String, path: String, gitHubRepo: String?) async {
        let project = Project(name: name, path: path, gitHubRepo: gitHubRepo)
        projects.append(project)

        do {
            try await persistence.saveProjects(projects)
        } catch {
            logger.error("Failed to save projects: \(error.localizedDescription)")
        }
    }

    func selectProject(_ project: Project) async {
        guard selectedProject?.id != project.id else { return }

        if isStreaming {
            await cancelStreaming()
        }

        selectedProject = project
        messages = []
        currentSessionId = project.lastSessionId

        await loadSessionHistory()

        // Reuse already-loaded sessions instead of reading disk again
        if let sessionId = currentSessionId,
           let session = sessions.first(where: { $0.id == sessionId }) {
            messages = cleanLoadedMessages(session.messages)
        }
    }

    func addProjectFromFolder(_ url: URL) async {
        let name = url.lastPathComponent
        let path = url.path
        await addProject(name: name, path: path, gitHubRepo: nil)

        // Auto-select the new project
        if let project = projects.last {
            await selectProject(project)
        }
    }

    // MARK: - Session Management

    func loadSessionHistory() async {
        guard let project = selectedProject else { return }
        sessions = await persistence.loadSessions(for: project.id)
    }

    func resumeSession(_ session: ChatSession) async {
        currentSessionId = session.id
        messages = cleanLoadedMessages(session.messages)

        if let index = projects.firstIndex(where: { $0.id == session.projectId }) {
            projects[index].lastSessionId = session.id
            if selectedProject?.id == session.projectId {
                selectedProject = projects[index]
            }
            do {
                try await persistence.saveProjects(projects)
            } catch {
                logger.error("Failed to save projects: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - GitHub

    func loginToGitHub() async throws -> DeviceCodeResponse {
        let response = try await github.startDeviceFlow()
        return response
    }

    func completeGitHubLogin(deviceCode: String, interval: Int) async throws {
        _ = try await github.pollForToken(deviceCode: deviceCode, interval: interval)

        let user = try await github.fetchUser()
        gitHubUser = user
        isLoggedIn = true
        onboardingCompleted = true

        // Cache user
        do {
            try await persistence.saveGitHubUser(user)
        } catch {
            logger.error("Failed to cache GitHub user: \(error.localizedDescription)")
        }

        // Setup SSH
        do {
            let publicKey = try await github.setupSSH()
            try await github.registerSSHKey(publicKey)
        } catch {
            // SSH setup failure is non-fatal
            logger.warning("SSH setup failed: \(error.localizedDescription)")
        }
    }

    func skipGitHubLogin() {
        onboardingCompleted = true
    }

    var isFetchingRepos = false

    func fetchRepos() async {
        isFetchingRepos = true
        defer { isFetchingRepos = false }
        do {
            repos = try await github.fetchRepos()
        } catch {
            handleError(error)
        }
    }

    func cloneAndAddProject(_ repo: GitHubRepo) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let clonePath = "\(home)/ClaudeWork/\(repo.name)"

        // Create the parent directory if needed
        let parentDir = "\(home)/ClaudeWork"
        let fm = FileManager.default
        if !fm.fileExists(atPath: parentDir) {
            try fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }

        // Clone the repo
        try await github.cloneRepo(repo, to: clonePath)

        // Add as a project
        await addProject(name: repo.name, path: clonePath, gitHubRepo: repo.fullName)

        // Auto-select the new project
        if let project = projects.last {
            await selectProject(project)
        }
    }

    // MARK: - Cancel

    func cancelStreaming() async {
        streamTask?.cancel()
        streamTask = nil
        await claude.cancel()

        flushTextDeltaBuffer()
        stopFlushTimer()
        isStreaming = false
        isThinking = false

        // Mark last message as done streaming
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant {
            messages[lastIndex].isStreaming = false
        }
    }

    // MARK: - View Convenience API

    var sessionsForSelectedProject: [ChatSession] {
        sessions // Already sorted by updatedAt in PersistenceService.loadSessions
    }

    var currentSession: ChatSession? {
        guard let id = currentSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    func startNewChat() {
        messages = []
        currentSessionId = nil
    }

    func selectSession(id: String) {
        guard currentSessionId != id else { return }
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        Task {
            await resumeSession(session)
        }
    }

    func addProject(_ project: Project) {
        projects.append(project)
        Task {
            do { try await persistence.saveProjects(projects) }
            catch { logger.error("Failed to save projects: \(error.localizedDescription)") }
        }
    }

    // MARK: - Private Helpers

    /// Collapse consecutive assistant messages (stale streaming snapshots) into one.
    private func cleanLoadedMessages(_ raw: [ChatMessage]) -> [ChatMessage] {
        var cleaned: [ChatMessage] = []
        for message in raw {
            var msg = message
            msg.isStreaming = false

            if msg.role == .assistant,
               let lastIndex = cleaned.indices.last,
               cleaned[lastIndex].role == .assistant {
                // Later snapshot is always more complete — replace
                cleaned[lastIndex] = msg
            } else {
                cleaned.append(msg)
            }
        }
        return cleaned
    }

    private func saveCurrentSession() async {
        guard let project = selectedProject,
              let sessionId = currentSessionId else { return }

        let firstUserContent = messages.first(where: { $0.role == .user })?.content
        let title: String
        if let content = firstUserContent {
            title = content.count > 50 ? String(content.prefix(50)) + "..." : content
        } else {
            title = "New Session"
        }

        let session = ChatSession(
            id: sessionId,
            projectId: project.id,
            title: String(title),
            messages: messages,
            updatedAt: Date()
        )

        do {
            try await persistence.saveSession(session)
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
        }

        // Update project's last session ID
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].lastSessionId = sessionId
            do {
                try await persistence.saveProjects(projects)
            } catch {
                logger.error("Failed to save projects: \(error.localizedDescription)")
            }
        }
    }

    private func handleError(_ error: Error) {
        logger.error("AppState error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showError = true
    }
}

// MARK: - App Errors

private enum AppError: LocalizedError {
    case noProjectSelected

    var errorDescription: String? {
        switch self {
        case .noProjectSelected:
            return "No project selected. Please select or add a project first."
        }
    }
}
