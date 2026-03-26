import SwiftUI

struct ToolResultView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(iconForTool(toolCall.name))
                        .font(.body)

                    Text(toolCall.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ClaudeTheme.textPrimary)

                    Spacer()

                    if toolCall.isError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(ClaudeTheme.statusError)
                            .font(.caption)
                            .accessibilityLabel("오류 발생")
                    } else if toolCall.result != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ClaudeTheme.statusSuccess)
                            .font(.caption)
                            .accessibilityLabel("완료")
                    } else {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityLabel("실행 중")
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(ClaudeTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            // Input summary
            Text(inputSummary)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textSecondary)
                .lineLimit(isExpanded ? nil : 1)

            // Expanded result
            if isExpanded, let result = toolCall.result {
                ClaudeThemeDivider()

                ScrollView {
                    Text(result)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(toolCall.isError ? ClaudeTheme.statusError : ClaudeTheme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(10)
        .background(
            toolCall.isError
                ? AnyShapeStyle(ClaudeTheme.statusError.opacity(0.06))
                : AnyShapeStyle(ClaudeTheme.surfacePrimary)
        )
        .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
                .strokeBorder(
                    toolCall.isError ? ClaudeTheme.statusError.opacity(0.3) : ClaudeTheme.border,
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Helpers

    private func iconForTool(_ name: String) -> String {
        let category = ToolCategory(toolName: name)
        switch category {
        case .readOnly:
            return name.lowercased() == "grep" ? "🔎" : "📂"
        default:
            return category.icon
        }
    }

    private var inputSummary: String {
        if let filePath = toolCall.input["file_path"]?.stringValue {
            let fileName = (filePath as NSString).lastPathComponent
            return "\(toolDescriptionPrefix) — \(fileName)"
        }
        if let command = toolCall.input["command"]?.stringValue {
            return "\(toolDescriptionPrefix) — \(command.count > 50 ? String(command.prefix(50)) + "..." : command)"
        }
        if let pattern = toolCall.input["pattern"]?.stringValue {
            return "\(toolDescriptionPrefix) — '\(pattern)'"
        }
        if let path = toolCall.input["path"]?.stringValue {
            let fileName = (path as NSString).lastPathComponent
            return "\(toolDescriptionPrefix) — \(fileName)"
        }

        return toolDescriptionPrefix
    }

    private var toolDescriptionPrefix: String {
        switch toolCall.name.lowercased() {
        case "read": "파일 내용 확인"
        case "edit": "파일 수정"
        case "write": "새 파일 생성"
        case "bash": "명령어 실행"
        case "glob": "파일 찾기"
        case "grep": "코드 내 검색"
        case "multiedit": "여러 곳 동시 수정"
        case "notebookedit": "노트북 수정"
        default: toolCall.name
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ToolResultView(toolCall: ToolCall(
            id: "1",
            name: "Read",
            input: ["file_path": .string("/src/main.swift")],
            result: "import Foundation\nprint(\"Hello\")",
            isError: false
        ))
        ToolResultView(toolCall: ToolCall(
            id: "2",
            name: "Bash",
            input: ["command": .string("ls -la")],
            result: nil,
            isError: false
        ))
        ToolResultView(toolCall: ToolCall(
            id: "3",
            name: "Edit",
            input: ["file_path": .string("/src/main.swift")],
            result: "Permission denied",
            isError: true
        ))
    }
    .padding()
    .frame(width: 400)
    .background(ClaudeTheme.background)
}
