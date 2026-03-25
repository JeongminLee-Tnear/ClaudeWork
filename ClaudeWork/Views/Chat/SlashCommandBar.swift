import SwiftUI

/// 대화 내용을 클립보드에 복사하는 버튼.
struct CopyConversationButton: View {
    let messages: [ChatMessage]
    @State private var isCopied = false

    var body: some View {
        Button {
            copyConversation()
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14))
                .foregroundStyle(isCopied ? .green : .secondary)
        }
        .buttonStyle(.borderless)
        .disabled(messages.isEmpty)
        .help(isCopied ? "복사됨" : "대화 내용 복사")
    }

    private func copyConversation() {
        let text = messages.map { msg in
            let role = msg.role == .user ? "나" : "Claude"
            return "[\(role)] \(msg.content)"
        }.joined(separator: "\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

#Preview {
    CopyConversationButton(messages: [
        ChatMessage(role: .user, content: "안녕"),
        ChatMessage(role: .assistant, content: "안녕하세요!"),
    ])
    .padding()
}
