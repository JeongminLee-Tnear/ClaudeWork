import SwiftUI

// MARK: - Markdown Content View

/// Renders markdown text with styled code blocks, headers, lists, and rich text.
struct MarkdownContentView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    headingView(level: level, content: content)
                case .text(let content):
                    markdownText(content)
                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code)
                case .orderedListItem(let number, let content):
                    listItemView(bullet: "\(number).", content: content)
                case .unorderedListItem(let content):
                    listItemView(bullet: "\u{2022}", content: content)
                case .blockquote(let content):
                    blockquoteView(content)
                case .horizontalRule:
                    Divider()
                        .padding(.vertical, 4)
                case .spacer:
                    Spacer().frame(height: 4)
                }
            }
        }
    }

    // MARK: - Heading View

    private func headingView(level: Int, content: String) -> some View {
        let attributed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )

        return VStack(alignment: .leading, spacing: 0) {
            Group {
                if let attributed {
                    Text(attributed)
                } else {
                    Text(content)
                }
            }
            .font(fontForHeading(level))
            .fontWeight(level <= 2 ? .bold : .semibold)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 8 : 4)
            .padding(.bottom, 2)

            if level <= 2 {
                Divider()
                    .opacity(0.4)
            }
        }
    }

    private func fontForHeading(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 26, weight: .bold)
        case 2: return .system(size: 22, weight: .bold)
        case 3: return .system(size: 18, weight: .semibold)
        case 4: return .system(size: 16, weight: .semibold)
        case 5: return .system(size: 14, weight: .medium)
        default: return .system(size: 13, weight: .medium)
        }
    }

    // MARK: - List Item View

    private func listItemView(bullet: String, content: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(bullet)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(minWidth: 16, alignment: .trailing)

            if let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
            } else {
                Text(content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Blockquote View

    private func blockquoteView(_ content: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)

            if let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.leading, 10)
            } else {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.leading, 10)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Rich Text Rendering

    private func markdownText(_ content: String) -> some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
            } else {
                Text(content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Block Parsing

    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentText = ""
        var inCodeBlock = false
        var codeLanguage = ""
        var codeContent = ""

        func flushText() {
            let trimmed = currentText.trimmingTrailingNewlines()
            if !trimmed.isEmpty {
                blocks.append(.text(trimmed))
            }
            currentText = ""
        }

        for line in lines {
            // Code block handling
            if !inCodeBlock && line.hasPrefix("```") {
                flushText()
                inCodeBlock = true
                codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeContent = ""
                continue
            }

            if inCodeBlock {
                if line.hasPrefix("```") {
                    blocks.append(.codeBlock(language: codeLanguage, code: codeContent.trimmingTrailingNewlines()))
                    inCodeBlock = false
                    codeLanguage = ""
                    codeContent = ""
                } else {
                    if !codeContent.isEmpty { codeContent += "\n" }
                    codeContent += line
                }
                continue
            }

            // Heading
            if let headingMatch = parseHeading(line) {
                flushText()
                blocks.append(.heading(level: headingMatch.level, content: headingMatch.content))
                continue
            }

            // Horizontal rule
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.count >= 3,
               (trimmedLine.allSatisfy({ $0 == "-" || $0 == " " }) && trimmedLine.contains("-")) ||
               (trimmedLine.allSatisfy({ $0 == "*" || $0 == " " }) && trimmedLine.contains("*")) ||
               (trimmedLine.allSatisfy({ $0 == "_" || $0 == " " }) && trimmedLine.contains("_")),
               trimmedLine.filter({ $0 != " " }).count >= 3 {
                flushText()
                blocks.append(.horizontalRule)
                continue
            }

            // Unordered list item
            if let listContent = parseUnorderedListItem(line) {
                flushText()
                blocks.append(.unorderedListItem(content: listContent))
                continue
            }

            // Ordered list item
            if let (number, listContent) = parseOrderedListItem(line) {
                flushText()
                blocks.append(.orderedListItem(number: number, content: listContent))
                continue
            }

            // Blockquote
            if trimmedLine.hasPrefix(">") {
                flushText()
                var quoteContent = String(trimmedLine.dropFirst())
                if quoteContent.hasPrefix(" ") {
                    quoteContent = String(quoteContent.dropFirst())
                }
                blocks.append(.blockquote(content: quoteContent))
                continue
            }

            // Empty line
            if trimmedLine.isEmpty {
                if !currentText.isEmpty {
                    flushText()
                    blocks.append(.spacer)
                }
                continue
            }

            // Regular text
            if !currentText.isEmpty { currentText += "\n" }
            currentText += line
        }

        // Handle remaining content
        if inCodeBlock && !codeContent.isEmpty {
            blocks.append(.codeBlock(language: codeLanguage, code: codeContent.trimmingTrailingNewlines()))
        } else {
            flushText()
        }

        return blocks
    }

    // MARK: - Line Parsers

    private func parseHeading(_ line: String) -> (level: Int, content: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        for char in trimmed {
            if char == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6, trimmed.count > level else { return nil }
        let rest = trimmed.dropFirst(level)
        guard rest.first == " " else { return nil }
        let content = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }
        return (level, content)
    }

    private func parseUnorderedListItem(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")) {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }

    private func parseOrderedListItem(_ line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let numberPart = trimmed[trimmed.startIndex..<dotIndex]
        guard let number = Int(numberPart), number >= 0 else { return nil }
        let afterDot = trimmed[trimmed.index(after: dotIndex)...]
        guard afterDot.hasPrefix(" ") else { return nil }
        return (number, String(afterDot.dropFirst()))
    }
}

// MARK: - Markdown Block

private enum MarkdownBlock {
    case heading(level: Int, content: String)
    case text(String)
    case codeBlock(language: String, code: String)
    case unorderedListItem(content: String)
    case orderedListItem(number: Int, content: String)
    case blockquote(content: String)
    case horizontalRule
    case spacer
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    copyButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            } else {
                HStack {
                    Spacer()
                    copyButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isCopied = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                Text(isCopied ? "복사됨" : "복사")
                    .font(.caption2)
            }
            .foregroundStyle(isCopied ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - String Extension

private extension String {
    func trimmingTrailingNewlines() -> String {
        var result = self
        while result.hasSuffix("\n") {
            result.removeLast()
        }
        return result
    }
}

// MARK: - Previews

#Preview("Markdown") {
    ScrollView {
        MarkdownContentView(text: """
        # H1 제목입니다
        ## H2 부제목입니다
        ### H3 소제목입니다
        #### H4 작은 제목

        이것은 **마크다운** 테스트입니다. `인라인 코드`도 지원합니다.

        > 인용문 블록입니다. 중요한 내용을 강조할 때 사용합니다.

        - 목록 아이템 1
        - 목록 아이템 2
        - **볼드** 목록 아이템 3

        1. 순서 있는 목록
        2. 두 번째 아이템
        3. 세 번째 아이템

        ---

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```

        일반 텍스트가 이어집니다.
        """)
        .padding()
    }
    .frame(width: 500, height: 600)
}
