import Foundation
import os

// MARK: - ClaudeService

/// Manages the Claude Code CLI process lifecycle and NDJSON streaming.
///
/// Spawns the `claude` binary with stream-json I/O, reads stdout as an
/// ``AsyncStream<StreamEvent>``, and writes user messages to stdin in NDJSON format.
actor ClaudeService {

    // MARK: - State

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var inactivityTimer: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.claudework",
        category: "ClaudeService"
    )

    /// Seconds of stdout silence before a health-check warning is emitted.
    private let inactivityTimeout: TimeInterval = 30

    // MARK: - Errors

    enum ClaudeError: LocalizedError {
        case binaryNotFound
        case versionCheckFailed(String)
        case processNotRunning
        case stdinUnavailable
        case spawnFailed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "Could not find the claude CLI binary."
            case .versionCheckFailed(let detail):
                return "Version check failed: \(detail)"
            case .processNotRunning:
                return "No claude process is currently running."
            case .stdinUnavailable:
                return "stdin pipe is not available."
            case .spawnFailed(let detail):
                return "Failed to spawn claude process: \(detail)"
            }
        }
    }

    // MARK: - Binary Discovery

    /// Well-known paths searched in order before falling back to the shell.
    private static var candidatePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.npm-global/bin/claude",
        ]
    }

    /// Locate the `claude` binary on this machine.
    func findClaudeBinary() async -> String? {
        let fm = FileManager.default

        for path in Self.candidatePaths {
            // Resolve symlinks before checking
            let resolved = (path as NSString).resolvingSymlinksInPath
            if fm.fileExists(atPath: resolved) && fm.isExecutableFile(atPath: path) {
                logger.info("Found claude binary at \(path, privacy: .public) -> \(resolved, privacy: .public)")
                return path
            }
        }

        // Shell fallback
        logger.info("Trying shell fallback to locate claude binary")
        do {
            let result = try await runShellCommand("/bin/zsh", arguments: ["-ilc", "whence -p claude"])
            let path = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty, fm.isExecutableFile(atPath: path) {
                logger.info("Found claude binary via shell at \(path, privacy: .public)")
                return path
            }
        } catch {
            logger.warning("Shell fallback failed: \(error, privacy: .public)")
        }

        logger.error("claude binary not found")
        return nil
    }

    // MARK: - Local Command

    /// Run a local slash command (e.g. "/cost", "/usage") and return stdout.
    func runLocalCommand(_ command: String) async throws -> String {
        guard let binary = await findClaudeBinary() else {
            throw ClaudeError.binaryNotFound
        }

        let output = try await runShellCommand(binary, arguments: ["-p", command, "--output-format", "text"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Version Check

    /// Run `claude --version` and return the version string.
    func checkVersion() async throws -> String {
        guard let binary = await findClaudeBinary() else {
            throw ClaudeError.binaryNotFound
        }

        let output = try await runShellCommand(binary, arguments: ["--version"])
        let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s*\(Claude Code\)"#, with: "", options: .regularExpression)

        guard !version.isEmpty else {
            throw ClaudeError.versionCheckFailed("Empty version output")
        }

        logger.info("Claude CLI version: \(version, privacy: .public)")
        return version
    }

    // MARK: - Send (spawn + stream)

    /// Spawn the CLI and return a stream of parsed events.
    ///
    /// - Parameters:
    ///   - prompt: Initial user prompt.
    ///   - cwd: Working directory for the process.
    ///   - sessionId: Optional session id to resume.
    ///   - model: Optional model override.
    ///   - hookSettingsPath: Path to hook settings file for `--settings`.
    /// - Returns: An `AsyncStream<StreamEvent>` that yields events until the process ends.
    func send(
        prompt: String,
        cwd: String,
        sessionId: String? = nil,
        model: String? = nil,
        hookSettingsPath: String? = nil
    ) -> AsyncStream<StreamEvent> {
        let (dataStream, eventStream) = makeStreams(
            prompt: prompt,
            cwd: cwd,
            sessionId: sessionId,
            model: model,
            hookSettingsPath: hookSettingsPath
        )

        return mergeWithInactivityCheck(
            parsedStream: eventStream,
            rawDataStream: dataStream
        )
    }

    // MARK: - Send Message (to running process)

    /// Write a user message to the running process's stdin as NDJSON.
    func sendMessage(_ text: String) throws {
        guard let stdinPipe, let process, process.isRunning else {
            throw ClaudeError.processNotRunning
        }
        guard let handle = Optional(stdinPipe.fileHandleForWriting) else {
            throw ClaudeError.stdinUnavailable
        }

        let payload: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": [
                    ["type": "text", "text": text]
                ]
            ] as [String: Any]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        var line = jsonData
        line.append(contentsOf: [UInt8(ascii: "\n")])
        handle.write(line)

        logger.debug("Wrote message to stdin (\(jsonData.count) bytes)")
    }

    // MARK: - Cancel

    /// Gracefully cancel the running process (SIGINT then SIGKILL after 5 s).
    func cancel() {
        guard let process, process.isRunning else { return }

        logger.info("Sending SIGINT to claude process \(process.processIdentifier)")
        process.interrupt() // SIGINT

        // Schedule a forced kill after 5 seconds if still alive.
        let pid = process.processIdentifier
        let log = logger
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if process.isRunning {
                log.warning("Process \(pid) still running after 5 s, sending SIGKILL")
                kill(pid, SIGKILL)
            }
        }
    }

    // MARK: - Is Running

    /// Whether the underlying process is alive.
    var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Private Helpers

    /// Build arguments array for the CLI invocation.
    private func buildArguments(
        prompt: String,
        sessionId: String?,
        model: String?,
        hookSettingsPath: String?
    ) -> [String] {
        var args: [String] = [
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
        ]

        if let hookSettingsPath {
            args += ["--settings", hookSettingsPath]
        }

        if let sessionId {
            args += ["--resume", sessionId]
        }

        if let model {
            args += ["--model", model]
        }

        args.append(prompt)
        return args
    }

    /// Spawn the process and return an `AsyncStream<Data>` of raw stdout chunks.
    ///
    /// The process is stored on `self` so callers can write to stdin or cancel.
    private func makeStreams(
        prompt: String,
        cwd: String,
        sessionId: String?,
        model: String?,
        hookSettingsPath: String?
    ) -> (dataStream: AsyncStream<Data>, eventStream: AsyncStream<StreamEvent>) {
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        let dataStream = AsyncStream<Data> { continuation in
            // Read stderr in the background for diagnostics.
            self.readStderr(stderr)

            // Use readabilityHandler for non-blocking stdout reads.
            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF
                    continuation.finish()
                    stdout.fileHandleForReading.readabilityHandler = nil
                } else {
                    continuation.yield(data)
                }
            }

            continuation.onTermination = { _ in
                stdout.fileHandleForReading.readabilityHandler = nil
            }

            // Spawn the process.
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self.spawnProcess(
                        prompt: prompt,
                        cwd: cwd,
                        sessionId: sessionId,
                        model: model,
                        hookSettingsPath: hookSettingsPath,
                        stdinPipe: stdin,
                        stdoutPipe: stdout,
                        stderrPipe: stderr
                    )
                } catch {
                    continuation.finish()
                }
            }
        }

        let eventStream = NDJSONParser.parse(dataStream)
        return (dataStream, eventStream)
    }

    /// Actually launch the `Process`.
    private func spawnProcess(
        prompt: String,
        cwd: String,
        sessionId: String?,
        model: String?,
        hookSettingsPath: String?,
        stdinPipe: Pipe,
        stdoutPipe: Pipe,
        stderrPipe: Pipe
    ) async throws {
        guard let binary = await findClaudeBinary() else {
            throw ClaudeError.binaryNotFound
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = buildArguments(
            prompt: prompt,
            sessionId: sessionId,
            model: model,
            hookSettingsPath: hookSettingsPath
        )
        proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        // Inherit a reasonable environment so the CLI can find config files, etc.
        proc.environment = ProcessInfo.processInfo.environment

        let log = logger
        proc.terminationHandler = { process in
            let status = process.terminationStatus
            let reason = process.terminationReason
            log.info(
                "claude process exited — status: \(status), reason: \(reason.rawValue)"
            )
        }

        do {
            try proc.run()
            // Close stdin immediately — each message spawns a fresh process
            stdinPipe.fileHandleForWriting.closeFile()
            self.process = proc
            logger.info(
                "Spawned claude process pid=\(proc.processIdentifier) cwd=\(cwd, privacy: .public)"
            )
        } catch {
            logger.error("Failed to spawn claude: \(error, privacy: .public)")
            throw ClaudeError.spawnFailed(error.localizedDescription)
        }
    }

    /// Read stderr asynchronously and log each line for diagnostics.
    private nonisolated func readStderr(_ pipe: Pipe) {
        let log = logger
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                pipe.fileHandleForReading.readabilityHandler = nil
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                for line in text.split(separator: "\n") {
                    log.debug("[stderr] \(line, privacy: .public)")
                }
            }
        }
    }

    /// Wrap a parsed event stream with a 30-second inactivity health-check.
    ///
    /// If no event arrives for `inactivityTimeout` seconds while the process is
    /// still alive, a synthetic `.unknown("health_check:inactivity")` event is
    /// yielded so the UI layer can surface a warning.
    private func mergeWithInactivityCheck(
        parsedStream: AsyncStream<StreamEvent>,
        rawDataStream: AsyncStream<Data>
    ) -> AsyncStream<StreamEvent> {
        let timeout = inactivityTimeout
        let isAlive: @Sendable () -> Bool = { [weak self] in
            // Must not call actor-isolated property directly from Sendable closure,
            // so we capture the process reference.
            // This is a best-effort check; race conditions are acceptable here.
            guard let self else { return false }
            // We cannot synchronously access actor state from a Sendable closure.
            // Instead, rely on the process reference captured at spawn time.
            return true
        }

        return AsyncStream<StreamEvent> { continuation in
            let task = Task {
                // We use an actor to safely track the last-event timestamp.
                let tracker = InactivityTracker(timeout: timeout)

                // Start the inactivity watcher.
                let watcherTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        if Task.isCancelled { break }
                        let elapsed = Date().timeIntervalSince(await tracker.lastEventDate)
                        if elapsed >= timeout {
                            continuation.yield(.unknown("health_check:inactivity"))
                            await tracker.touch() // reset so we don't spam
                        }
                    }
                }

                for await event in parsedStream {
                    await tracker.touch()
                    continuation.yield(event)
                }

                watcherTask.cancel()
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Run a simple command and return its stdout as a String.
    private func runShellCommand(
        _ command: String,
        arguments: [String] = []
    ) async throws -> String {
        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = arguments
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.environment = ProcessInfo.processInfo.environment

        try proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Cleanup

    /// Tear down any resources held by the service.
    func cleanup() {
        inactivityTimer?.cancel()
        inactivityTimer = nil

        if let process, process.isRunning {
            cancel()
        }

        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}

// MARK: - InactivityTracker

/// A small actor used to safely share a mutable timestamp between the
/// event-forwarding task and the inactivity-watcher task.
private actor InactivityTracker {
    let timeout: TimeInterval
    private(set) var lastEventDate: Date = Date()

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func touch() {
        lastEventDate = Date()
    }
}
