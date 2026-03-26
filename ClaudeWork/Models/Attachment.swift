import Foundation
import AppKit

// MARK: - Attachment

struct Attachment: Identifiable, Sendable {
    let id: UUID
    let type: AttachmentType
    let name: String
    let path: String
    let fileSize: Int64?
    let thumbnail: Data?
    let textContent: String?

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        name: String,
        path: String = "",
        fileSize: Int64? = nil,
        thumbnail: Data? = nil,
        textContent: String? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.path = path
        self.fileSize = fileSize
        self.thumbnail = thumbnail
        self.textContent = textContent
    }

    enum AttachmentType: String, Sendable {
        case image
        case file
        case text
    }

    /// 프롬프트에 삽입할 첨부 컨텍스트 문자열
    var promptContext: String {
        if type == .text, let text = textContent {
            return "[Pasted text:\n\(text)\n]"
        }
        return "[Attached \(type.rawValue): \(path)]"
    }
}

// MARK: - Attachment Factory

enum AttachmentFactory {

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"
    ]

    private static var tempDirectory: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeWork-Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 클립보드 이미지로부터 Attachment 생성 (PNG 임시파일 저장)
    static func fromClipboardImage(_ image: NSImage) -> Attachment? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let fileName = "clipboard-\(UUID().uuidString.prefix(8)).png"
        let filePath = tempDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: filePath)
        } catch {
            return nil
        }

        // 썸네일 생성 (최대 80x80)
        let thumbnailData = generateThumbnail(from: image, maxSize: 200)

        return Attachment(
            type: .image,
            name: fileName,
            path: filePath.path,
            fileSize: Int64(pngData.count),
            thumbnail: thumbnailData
        )
    }

    /// 파일 URL로부터 Attachment 생성
    static func fromFileURL(_ url: URL) -> Attachment? {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type: Attachment.AttachmentType = imageExtensions.contains(ext) ? .image : .file

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64

        var thumbnail: Data?
        if type == .image, let image = NSImage(contentsOf: url) {
            thumbnail = generateThumbnail(from: image, maxSize: 200)
        }

        return Attachment(
            type: type,
            name: name,
            path: url.path,
            fileSize: fileSize,
            thumbnail: thumbnail
        )
    }

    /// 긴 텍스트 붙여넣기 임계값 (이 길이 이상이면 텍스트 첨부로 처리)
    static let longTextThreshold = 300
    /// 텍스트 첨부 최대 길이 (100KB)
    static let maxTextLength = 100_000

    /// 긴 텍스트로부터 Attachment 생성
    static func fromLongText(_ text: String) -> Attachment {
        let truncated = text.count > maxTextLength ? String(text.prefix(maxTextLength)) : text
        let lineCount = truncated.components(separatedBy: .newlines).count
        let charCount = truncated.count
        let suffix = text.count > maxTextLength ? " (잘림)" : ""
        let name = "붙여넣은 텍스트 (\(lineCount)줄, \(charCount)자\(suffix))"

        return Attachment(
            type: .text,
            name: name,
            textContent: truncated
        )
    }

    private static func generateThumbnail(from image: NSImage, maxSize: CGFloat) -> Data? {
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()

        guard let tiff = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
