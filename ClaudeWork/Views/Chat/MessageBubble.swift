import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
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
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Text Bubble

    @ViewBuilder
    private var textBubble: some View {
        if message.role == .user {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground, in: bubbleShape)
                .accessibilityLabel("내 메시지: \(message.content)")
        } else {
            MarkdownContentView(text: message.content)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground, in: bubbleShape)
                .accessibilityLabel("어시스턴트: \(message.content)")
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color.accentColor)
        } else {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            return UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 4,
                topTrailingRadius: 12
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 12,
                topTrailingRadius: 12
            )
        }
    }

    // MARK: - Streaming Indicator

    private var pulsingDot: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
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
}
