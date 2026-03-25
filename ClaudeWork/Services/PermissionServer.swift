import Foundation
import Network
import os

// MARK: - PermissionServer

/// An actor that runs a local HTTP server using NWListener to receive
/// PreToolUse hook requests from the Claude CLI and hold connections
/// open until the UI responds with allow/deny.
actor PermissionServer {

    // MARK: - Constants

    private static let basePort: UInt16 = 19836
    private static let maxPort: UInt16 = 19846
    private static let timeoutSeconds: UInt64 = 300 // 5 minutes

    // MARK: - Properties

    private var listener: NWListener?
    private(set) var port: UInt16 = PermissionServer.basePort
    private let appSecret = UUID().uuidString
    private var runToken = UUID().uuidString
    private let logger = Logger(subsystem: "com.claudework", category: "PermissionServer")

    /// Pending permission continuations keyed by tool_use_id.
    private var pendingContinuations: [String: CheckedContinuation<PermissionDecision, Never>] = [:]

    /// Continuation backing the public AsyncStream of permission requests.
    private var requestContinuation: AsyncStream<PermissionRequest>.Continuation?

    /// Stream consumed by the UI (AppState) to present permission prompts.
    nonisolated let permissionRequests: AsyncStream<PermissionRequest>

    // MARK: - Init

    init() {
        var continuation: AsyncStream<PermissionRequest>.Continuation!
        self.permissionRequests = AsyncStream { continuation = $0 }
        self.requestContinuation = continuation
    }

    // MARK: - Lifecycle

    /// Start the TCP listener, auto-incrementing the port on conflict.
    func start() async throws {
        for candidatePort in Self.basePort...Self.maxPort {
            do {
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: candidatePort)!)
                self.port = candidatePort
                self.listener = l

                // Use a detached task to handle state updates since NWListener
                // callbacks are on an internal queue.
                let serverPort = candidatePort
                let logger = self.logger

                l.stateUpdateHandler = { [weak l] state in
                    switch state {
                    case .ready:
                        logger.info("PermissionServer listening on port \(serverPort)")
                    case .failed(let error):
                        logger.error("Listener failed: \(error.localizedDescription)")
                        l?.cancel()
                    default:
                        break
                    }
                }

                l.newConnectionHandler = { [weak self] connection in
                    guard let self else { return }
                    Task { await self.handleConnection(connection) }
                }

                l.start(queue: .global(qos: .userInitiated))
                logger.info("Attempting to listen on port \(serverPort)")
                return
            } catch {
                logger.warning("Port \(candidatePort) unavailable, trying next…")
                continue
            }
        }
        throw PermissionServerError.noAvailablePort
    }

    /// Stop the listener and deny all pending requests.
    func stop() {
        listener?.cancel()
        listener = nil

        // Deny everything that's still pending.
        for (id, continuation) in pendingContinuations {
            logger.info("Denying pending request \(id) on server stop")
            continuation.resume(returning: .deny)
        }
        pendingContinuations.removeAll()
        requestContinuation?.finish()
    }

    // MARK: - Public API

    /// Called by the UI when the user makes a decision.
    func respond(toolUseId: String, decision: PermissionDecision) {
        guard let continuation = pendingContinuations.removeValue(forKey: toolUseId) else {
            logger.warning("No pending continuation for toolUseId \(toolUseId)")
            return
        }
        continuation.resume(returning: decision)
    }

    /// Refresh the run token (call at the start of each CLI session).
    func refreshRunToken() {
        runToken = UUID().uuidString
    }

    /// The current run token for building the hook URL.
    func currentRunToken() -> String {
        runToken
    }

    // MARK: - Hook Settings

    /// Generate the hook settings JSON that should be passed to `claude --settings`.
    func generateHookSettings() -> String {
        let url = "http://127.0.0.1:\(port)/hook/pre-tool-use/\(appSecret)/\(runToken)"
        let settings: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    [
                        "matcher": "^(Bash|Edit|Write|MultiEdit|mcp__.*)$",
                        "hooks": [
                            [
                                "type": "http",
                                "url": url,
                                "timeout": 300
                            ]
                        ]
                    ]
                ]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    /// Write hook settings to a temporary file and return its path.
    func writeHookSettingsFile() throws -> String {
        let json = generateHookSettings()
        let tempDir = FileManager.default.temporaryDirectory
        let filePath = tempDir.appendingPathComponent("claudework-hooks-\(UUID().uuidString).json")
        try json.write(to: filePath, atomically: true, encoding: .utf8)
        return filePath.path
    }

    // MARK: - Connection Handling

    /// Handle a single inbound TCP connection.
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        Task {
            do {
                let rawRequest = try await readHTTPRequest(connection)
                let (method, path, body) = try parseHTTPRequest(rawRequest)

                guard method == "POST" else {
                    await sendHTTPResponse(connection, status: "405 Method Not Allowed", body: #"{"error":"method not allowed"}"#)
                    return
                }

                // Validate path: /hook/pre-tool-use/{appSecret}/{runToken}
                let components = path.split(separator: "/").map(String.init)
                guard components.count == 5,
                      components[0] == "hook",
                      components[1] == "pre-tool-use",
                      components[2] == appSecret,
                      components[3] == runToken else {
                    logger.warning("Invalid path or secret: \(path)")
                    await sendHTTPResponse(connection, status: "403 Forbidden", body: #"{"error":"invalid path"}"#)
                    return
                }

                // Parse the JSON body.
                guard let bodyData = body.data(using: .utf8) else {
                    await sendHTTPResponse(connection, status: "400 Bad Request", body: #"{"error":"invalid body"}"#)
                    return
                }

                let hookRequest = try JSONDecoder().decode(HookRequestBody.self, from: bodyData)

                let permissionRequest = PermissionRequest(
                    id: hookRequest.toolUseId,
                    toolName: hookRequest.toolName,
                    toolInput: hookRequest.toolInput,
                    runToken: runToken
                )

                // Emit request to the UI stream.
                requestContinuation?.yield(permissionRequest)

                // Hold the connection open until the UI responds or we time out.
                let decision = await waitForDecision(toolUseId: hookRequest.toolUseId)

                let responseBody = HookResponseBody(
                    hookSpecificOutput: .init(
                        hookEventName: "PreToolUse",
                        permissionDecision: decision.rawValue,
                        permissionDecisionReason: decision == .allow ? "User approved" : "User denied"
                    )
                )

                let responseData = try JSONEncoder().encode(responseBody)
                let responseJSON = String(data: responseData, encoding: .utf8) ?? "{}"
                await sendHTTPResponse(connection, status: "200 OK", body: responseJSON)

            } catch {
                logger.error("Error handling connection: \(error.localizedDescription)")
                await sendHTTPResponse(connection, status: "500 Internal Server Error", body: #"{"error":"internal error"}"#)
            }
        }
    }

    /// Wait for a UI decision with a 5-minute timeout.
    private func waitForDecision(toolUseId: String) async -> PermissionDecision {
        await withTaskGroup(of: PermissionDecision.self) { group in
            group.addTask {
                await withCheckedContinuation { (continuation: CheckedContinuation<PermissionDecision, Never>) in
                    Task { await self.registerContinuation(toolUseId: toolUseId, continuation: continuation) }
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(Self.timeoutSeconds) * 1_000_000_000)
                return .deny
            }

            // Whichever finishes first wins.
            let decision = await group.next()!
            group.cancelAll()

            // If the timeout won, clean up the pending continuation.
            if decision == .deny {
                Task { await self.cancelPendingIfNeeded(toolUseId: toolUseId) }
            }

            return decision
        }
    }

    private func registerContinuation(toolUseId: String, continuation: CheckedContinuation<PermissionDecision, Never>) {
        pendingContinuations[toolUseId] = continuation
    }

    /// Remove and resume a pending continuation with .deny if it still exists (timeout case).
    private func cancelPendingIfNeeded(toolUseId: String) {
        if let continuation = pendingContinuations.removeValue(forKey: toolUseId) {
            continuation.resume(returning: .deny)
        }
    }

    // MARK: - TCP / HTTP Helpers

    /// Read raw bytes from the connection until we have a complete HTTP request.
    private func readHTTPRequest(_ connection: NWConnection) async throws -> Data {
        var buffer = Data()
        let headerEnd = Data("\r\n\r\n".utf8)

        // Phase 1: Read until we find the end of headers.
        while !buffer.contains(headerEnd) {
            let chunk = try await readChunk(connection, maxLength: 8192)
            guard !chunk.isEmpty else { throw PermissionServerError.connectionClosed }
            buffer.append(chunk)
        }

        // Phase 2: If there's a Content-Length, read the body too.
        guard let headerRange = buffer.range(of: headerEnd) else {
            throw PermissionServerError.malformedRequest
        }
        let headerData = buffer[buffer.startIndex..<headerRange.lowerBound]
        let headerString = String(data: headerData, encoding: .utf8) ?? ""
        let contentLength = parseContentLength(from: headerString)

        if contentLength > 0 {
            let bodyStart = headerRange.upperBound
            let bodyBytesRead = buffer.count - buffer.distance(from: buffer.startIndex, to: bodyStart)
            var remaining = contentLength - bodyBytesRead
            while remaining > 0 {
                let chunk = try await readChunk(connection, maxLength: min(remaining, 8192))
                guard !chunk.isEmpty else { throw PermissionServerError.connectionClosed }
                buffer.append(chunk)
                remaining -= chunk.count
            }
        }

        return buffer
    }

    /// Read a single chunk from the connection.
    private func readChunk(_ connection: NWConnection, maxLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    /// Parse the HTTP request into method, path, and body.
    private func parseHTTPRequest(_ data: Data) throws -> (method: String, path: String, body: String) {
        let headerEnd = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: headerEnd) else {
            throw PermissionServerError.malformedRequest
        }

        let headerData = data[data.startIndex..<headerRange.lowerBound]
        let bodyData = data[headerRange.upperBound...]

        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw PermissionServerError.malformedRequest
        }

        let lines = headerString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw PermissionServerError.malformedRequest
        }

        // "POST /hook/pre-tool-use/{secret}/{token} HTTP/1.1"
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            throw PermissionServerError.malformedRequest
        }

        let method = parts[0]
        let path = parts[1]
        let body = String(data: bodyData, encoding: .utf8) ?? ""

        return (method, path, body)
    }

    /// Extract Content-Length from raw headers string.
    private func parseContentLength(from headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    /// Send a complete HTTP response and close the connection.
    private func sendHTTPResponse(_ connection: NWConnection, status: String, body: String) async {
        let bodyData = Data(body.utf8)
        let response = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        var payload = Data(response.utf8)
        payload.append(bodyData)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: payload, completion: .contentProcessed { _ in
                connection.cancel()
                continuation.resume()
            })
        }
    }
}

// MARK: - Data Extension

private extension Data {
    func contains(_ other: Data) -> Bool {
        range(of: other) != nil
    }
}

// MARK: - Request / Response Codables

/// The JSON body sent by the Claude CLI hook.
private struct HookRequestBody: Decodable {
    let hookEventName: String
    let toolName: String
    let toolInput: [String: JSONValue]
    let toolUseId: String

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
    }
}

/// The JSON response body returned to the Claude CLI.
private struct HookResponseBody: Encodable {
    let hookSpecificOutput: HookOutput

    struct HookOutput: Encodable {
        let hookEventName: String
        let permissionDecision: String
        let permissionDecisionReason: String
    }
}

// MARK: - Errors

enum PermissionServerError: LocalizedError {
    case noAvailablePort
    case connectionClosed
    case malformedRequest

    var errorDescription: String? {
        switch self {
        case .noAvailablePort: return "No available port in range 19836–19846"
        case .connectionClosed: return "Connection closed unexpectedly"
        case .malformedRequest: return "Malformed HTTP request"
        }
    }
}
