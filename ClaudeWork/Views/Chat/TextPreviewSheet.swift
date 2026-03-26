import SwiftUI

/// 텍스트 첨부파일 상세 미리보기 시트
struct TextPreviewSheet: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(ClaudeTheme.accent)
                Text(attachment.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ClaudeTheme.textPrimary)

                Spacer()

                Button {
                    if let text = attachment.textContent {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("복사")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 텍스트 내용
            ScrollView {
                if let text = attachment.textContent {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            .background(ClaudeTheme.background)
        }
        .frame(width: 600, height: 450)
        .background(ClaudeTheme.surfaceElevated)
    }
}
