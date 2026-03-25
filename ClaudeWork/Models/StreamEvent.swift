import Foundation

// MARK: - Stream Event (Top-Level)

/// Represents a single event from the Claude CLI NDJSON stream.
/// Decoding logic is in StreamEventDecoding.swift.
enum StreamEvent: Sendable {
    case system(SystemEvent)
    case assistant(AssistantMessage)
    case user(UserMessage)
    case result(ResultEvent)
    case rateLimitEvent(RateLimitInfo)
    case unknown(String)
}

// MARK: - System Event

struct SystemEvent: Sendable {
    let subtype: String
    let sessionId: String?
    let tools: [String]?
    let model: String?
    let claudeCodeVersion: String?
}

// MARK: - Assistant Message

struct AssistantMessage: Sendable {
    let role: String
    let content: [ContentBlock]
}

// MARK: - Content Block

enum ContentBlock: Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case thinking(String)
}

// MARK: - User Message (Tool Result)

struct UserMessage: Sendable {
    let toolUseId: String
    let content: String
    let isError: Bool
}

// MARK: - Result Event

struct ResultEvent: Sendable {
    let durationMs: Double?
    let totalCostUsd: Double?
    let sessionId: String
    let isError: Bool
    let totalTurns: Int?
}

// MARK: - Rate Limit Info

struct RateLimitInfo: Sendable {
    let status: String
    let retrySec: Double?
}
