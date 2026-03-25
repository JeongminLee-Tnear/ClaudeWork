import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: Role
    var content: String
    var toolCalls: [ToolCall]
    var isStreaming: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String = "",
        toolCalls: [ToolCall] = [],
        isStreaming: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.isStreaming = isStreaming
        self.timestamp = timestamp
    }
}

// MARK: - Role

enum Role: String, Codable, Sendable {
    case user
    case assistant
}

// MARK: - Tool Call

struct ToolCall: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let input: [String: JSONValue]
    var result: String?
    var isError: Bool

    init(
        id: String,
        name: String,
        input: [String: JSONValue] = [:],
        result: String? = nil,
        isError: Bool = false
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.result = result
        self.isError = isError
    }
}
