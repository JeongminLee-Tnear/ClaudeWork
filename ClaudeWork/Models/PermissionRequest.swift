import Foundation

// MARK: - Permission Request

struct PermissionRequest: Identifiable, Sendable {
    let id: String
    let toolName: String
    let toolInput: [String: JSONValue]
    let runToken: String

    var riskLevel: RiskLevel {
        ToolCategory(toolName: toolName).riskLevel
    }
}

// MARK: - Risk Level

enum RiskLevel: Sendable {
    /// Read-only operations: Read, Glob, Grep
    case safe
    /// File modification operations: Edit, Write, MultiEdit
    case moderate
    /// Arbitrary execution: Bash, mcp__*
    case high

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
}

// MARK: - Tool Category

enum ToolCategory: Sendable {
    case readOnly
    case fileModification
    case execution
    case mcp
    case unknown

    init(toolName: String) {
        switch toolName.lowercased() {
        case "read", "glob", "grep", "list", "search":
            self = .readOnly
        case "edit", "write", "multiedit", "multi_edit":
            self = .fileModification
        case "bash", "execute":
            self = .execution
        default:
            if toolName.lowercased().hasPrefix("mcp__") {
                self = .mcp
            } else {
                self = .unknown
            }
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .readOnly: return .safe
        case .fileModification, .unknown: return .moderate
        case .execution, .mcp: return .high
        }
    }

    var icon: String {
        switch self {
        case .readOnly: return "📂"
        case .fileModification: return "✏️"
        case .execution: return "💻"
        case .mcp: return "🔌"
        case .unknown: return "🔧"
        }
    }
}

// MARK: - Permission Decision

enum PermissionDecision: String, Sendable {
    case allow
    case deny
}
