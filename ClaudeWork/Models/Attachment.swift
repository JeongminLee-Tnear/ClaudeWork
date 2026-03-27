import Foundation
import AppKit

// MARK: - Attachment

struct Attachment: Identifiable, Sendable {
    let id: UUID
    let type: AttachmentType
    let name: String
    let path: String
    let fileSize: Int64?
    let textContent: String?
    let imageData: Data?

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        name: String,
        path: String = "",
        fileSize: Int64? = nil,
        textContent: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.path = path
        self.fileSize = fileSize
        self.textContent = textContent
        self.imageData = imageData
    }

    enum AttachmentType: String, Sendable {
        case image
        case file
        case text
    }

    var promptContext: String {
        if type == .text, let text = textContent {
            return "[Pasted text:\n\(text)\n]"
        }
        return "[Attached \(type.rawValue): \(path)]"
    }
}

// MARK: - Attachment Factory

enum AttachmentFactory {

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "heic"
    ]

    /// 파일 URL로부터 Attachment 생성
    static func fromFileURL(_ url: URL) -> Attachment? {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type: Attachment.AttachmentType = imageExtensions.contains(ext) ? .image : .file
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
        let imgData: Data? = type == .image ? (try? Data(contentsOf: url)) : nil

        return Attachment(
            type: type,
            name: name,
            path: url.path,
            fileSize: fileSize,
            imageData: imgData
        )
    }

    /// 긴 텍스트 붙여넣기 임계값
    static let longTextThreshold = 300
    static let maxTextLength = 100_000

    /// 긴 텍스트로부터 Attachment 생성
    static func fromLongText(_ text: String) -> Attachment {
        let truncated = text.count > maxTextLength ? String(text.prefix(maxTextLength)) : text
        let lineCount = truncated.components(separatedBy: .newlines).count
        let charCount = truncated.count
        let suffix = text.count > maxTextLength ? " (잘림)" : ""
        let name = "붙여넣은 텍스트 (\(lineCount)줄, \(charCount)자\(suffix))"

        return Attachment(type: .text, name: name, textContent: truncated)
    }
}
