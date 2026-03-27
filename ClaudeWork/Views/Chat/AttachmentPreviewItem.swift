import SwiftUI

/// 첨부파일 프리뷰 아이템 — 세로가 긴 직사각형 카드
/// 마우스 호버 시 X 버튼 오버레이 표시
struct AttachmentPreviewItem: View {
    let attachment: Attachment
    let onRemove: () -> Void
    var onTap: (() -> Void)?

    @State private var isHovered = false

    private let cardWidth: CGFloat = 80
    private let cardHeight: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardContent
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ClaudeTheme.inputBorder.opacity(0.5), lineWidth: 1)
                )

            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.3))
                    .frame(width: cardWidth, height: cardHeight)

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.borderless)
                .offset(x: -4, y: 4)
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap?()
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch attachment.type {
        case .image:
            imageCard
        case .file:
            fileCard
        case .text:
            textCard
        }
    }

    // MARK: - Image Card

    @State private var renderedImage: CGImage?

    private var imageCard: some View {
        ZStack(alignment: .bottom) {
            if let cgImage = renderedImage {
                Image(decorative: cgImage, scale: 2.0)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else {
                ClaudeTheme.surfaceSecondary
                    .frame(width: cardWidth, height: cardHeight)
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }

            Text(attachment.name)
                .font(.system(size: 8))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.5))
        }
        .task(id: attachment.id) {
            renderedImage = makeCGImage()
        }
    }

    private func makeCGImage() -> CGImage? {
        guard let data = attachment.imageData else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - File Card

    private var fileCard: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundStyle(ClaudeTheme.accent)
            Text(attachment.name)
                .font(.system(size: 9))
                .foregroundStyle(ClaudeTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(ClaudeTheme.surfaceSecondary)
    }

    // MARK: - Text Card

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let text = attachment.textContent {
                Text(text.prefix(200))
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .lineLimit(nil)
                    .padding(4)
            }
            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Image(systemName: "doc.text")
                    .font(.system(size: 7))
                Text(shortTextName)
                    .font(.system(size: 7))
                    .lineLimit(1)
            }
            .foregroundStyle(ClaudeTheme.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClaudeTheme.surfaceSecondary)
        }
        .background(ClaudeTheme.background)
    }

    private var shortTextName: String {
        if let text = attachment.textContent {
            let lines = text.components(separatedBy: .newlines).count
            return "\(lines)줄"
        }
        return ""
    }
}
