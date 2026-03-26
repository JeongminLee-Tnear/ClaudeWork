import Foundation

// MARK: - StreamEvent Decodable

extension StreamEvent: Decodable {
    private enum RootCodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootCodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "system":
            let event = try SystemEvent(from: decoder)
            self = .system(event)
        case "assistant":
            let message = try AssistantMessage(from: decoder)
            self = .assistant(message)
        case "user":
            let message = try UserMessage(from: decoder)
            self = .user(message)
        case "result":
            let event = try ResultEvent(from: decoder)
            self = .result(event)
        case "rate_limit_event":
            let info = try RateLimitInfo(from: decoder)
            self = .rateLimitEvent(info)
        default:
            // Capture the raw JSON string for unknown types
            let rawData = try JSONEncoder().encode(JSONValue(from: decoder))
            let rawString = String(data: rawData, encoding: .utf8) ?? "{\"type\": \"\(type)\"}"
            self = .unknown(rawString)
        }
    }
}

// MARK: - SystemEvent Decodable

extension SystemEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case subtype
        case sessionId = "session_id"
        case tools
        case model
        case claudeCodeVersion = "claude_code_version"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.subtype = try container.decodeIfPresent(String.self, forKey: .subtype) ?? "unknown"
        self.sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        self.tools = try container.decodeIfPresent([String].self, forKey: .tools)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.claudeCodeVersion = try container.decodeIfPresent(String.self, forKey: .claudeCodeVersion)
    }
}

// MARK: - AssistantMessage Decodable

extension AssistantMessage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case message
    }

    private enum MessageCodingKeys: String, CodingKey {
        case role
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messageContainer = try container.nestedContainer(
            keyedBy: MessageCodingKeys.self,
            forKey: .message
        )
        self.role = try messageContainer.decode(String.self, forKey: .role)
        self.content = try messageContainer.decode([ContentBlock].self, forKey: .content)
    }
}

// MARK: - ContentBlock Decodable

extension ContentBlock: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case thinking
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decodeIfPresent([String: JSONValue].self, forKey: .input) ?? [:]
            self = .toolUse(id: id, name: name, input: input)
        case "thinking":
            let thinking = try container.decode(String.self, forKey: .thinking)
            self = .thinking(thinking)
        default:
            // Treat unknown content block types as text with a description
            let text = try container.decodeIfPresent(String.self, forKey: .text)
                ?? "[Unknown content block: \(type)]"
            self = .text(text)
        }
    }
}

// MARK: - UserMessage Decodable

extension UserMessage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case message
    }

    private enum MessageCodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let messageContainer = try container.nestedContainer(
            keyedBy: MessageCodingKeys.self,
            forKey: .message
        )
        self.toolUseId = try messageContainer.decode(String.self, forKey: .toolUseId)
        self.content = try messageContainer.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.isError = try messageContainer.decodeIfPresent(Bool.self, forKey: .isError) ?? false
    }
}

// MARK: - UsageInfo Decodable

extension UsageInfo: Decodable {
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        self.outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        self.cacheCreationInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens) ?? 0
        self.cacheReadInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens) ?? 0
    }
}

// MARK: - ResultEvent Decodable

extension ResultEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case durationMs = "duration_ms"
        case totalCostUsd = "total_cost_usd"
        case sessionId = "session_id"
        case isError = "is_error"
        case totalTurns = "total_turns"
        case usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.durationMs = try container.decodeIfPresent(Double.self, forKey: .durationMs)
        self.totalCostUsd = try container.decodeIfPresent(Double.self, forKey: .totalCostUsd)
        self.sessionId = try container.decode(String.self, forKey: .sessionId)
        self.isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        self.totalTurns = try container.decodeIfPresent(Int.self, forKey: .totalTurns)
        self.usage = try container.decodeIfPresent(UsageInfo.self, forKey: .usage)
    }
}

// MARK: - RateLimitInfo Decodable

extension RateLimitInfo: Decodable {
    private enum CodingKeys: String, CodingKey {
        case status
        case retrySec = "retry_sec"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(String.self, forKey: .status)
        self.retrySec = try container.decodeIfPresent(Double.self, forKey: .retrySec)
    }
}
