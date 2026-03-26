import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 80)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // 첨부파일 표시
                if !message.attachmentPaths.isEmpty {
                    attachmentPreview
                }

                // Text content
                if !message.content.isEmpty {
                    textBubble
                }

                // Tool calls
                ForEach(message.toolCalls) { toolCall in
                    ToolResultView(toolCall: toolCall)
                }

                // Streaming indicator
                if message.isStreaming {
                    pulsingDot
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Text Bubble

    @ViewBuilder
    private var textBubble: some View {
        if message.role == .user {
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(ClaudeTheme.userBubbleText)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(ClaudeTheme.userBubble, in: bubbleShape)
                .accessibilityLabel("내 메시지: \(message.content)")
        } else {
            MarkdownContentView(text: message.content)
                .foregroundStyle(ClaudeTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(ClaudeTheme.assistantBubble, in: bubbleShape)
                .overlay(
                    bubbleShape
                        .strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
                )
                .accessibilityLabel("어시스턴트: \(message.content)")
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            return UnevenRoundedRectangle(
                topLeadingRadius: ClaudeTheme.cornerRadiusLarge,
                bottomLeadingRadius: ClaudeTheme.cornerRadiusLarge,
                bottomTrailingRadius: 4,
                topTrailingRadius: ClaudeTheme.cornerRadiusLarge
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: ClaudeTheme.cornerRadiusLarge,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: ClaudeTheme.cornerRadiusLarge,
                topTrailingRadius: ClaudeTheme.cornerRadiusLarge
            )
        }
    }

    // MARK: - Attachment Preview

    private var attachmentPreview: some View {
        HStack(spacing: 6) {
            ForEach(message.attachmentPaths, id: \.path) { info in
                HStack(spacing: 4) {
                    if info.isImage, let nsImage = NSImage(contentsOfFile: info.path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: info.isImage ? "photo" : "doc")
                            .font(.system(size: 14))
                            .foregroundStyle(ClaudeTheme.accent)
                    }
                    Text(info.name)
                        .font(.caption)
                        .foregroundStyle(ClaudeTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(6)
                .background(ClaudeTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
            }
        }
    }

    // MARK: - Streaming Indicator

    private var pulsingDot: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(ClaudeTheme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: message.isStreaming
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ClaudeTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessage(role: .user, content: "Hello!"))
        MessageBubble(message: ChatMessage(role: .assistant, content: "안녕하세요! **무엇을** 도와드릴까요?\n\n```swift\nprint(\"Hello\")\n```\n\n- 항목 1\n- 항목 2"))
        MessageBubble(message: ChatMessage(role: .assistant, content: "", isStreaming: true))
    }
    .padding()
    .frame(width: 500)
    .background(ClaudeTheme.background)
}
