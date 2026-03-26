import SwiftUI

// MARK: - Markdown Content View

/// Renders markdown text with styled code blocks, headers, lists, and rich text.
struct MarkdownContentView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    headingView(level: level, content: content)
                case .text(let content):
                    markdownText(content)
                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code)
                        .padding(.vertical, 4)
                case .orderedListItem(let number, let content):
                    listItemView(bullet: "\(number).", content: content)
                case .unorderedListItem(let content):
                    listItemView(bullet: "\u{2022}", content: content)
                case .blockquote(let content):
                    blockquoteView(content)
                case .table(let headers, let rows):
                    MarkdownTableView(headers: headers, rows: rows)
                        .padding(.vertical, 4)
                case .horizontalRule:
                    ClaudeThemeDivider()
                        .padding(.vertical, 4)
                case .spacer:
                    Spacer().frame(height: 8)
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
            .foregroundStyle(ClaudeTheme.textPrimary)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 16 : 10)
            .padding(.bottom, 4)

            if level <= 2 {
                Rectangle()
                    .fill(ClaudeTheme.border)
                    .frame(height: 1)
                    .opacity(0.5)
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
                .foregroundStyle(ClaudeTheme.accent)
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
            RoundedRectangle(cornerRadius: 1.5)
                .fill(ClaudeTheme.accent.opacity(0.6))
                .frame(width: 3)

            if let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 14))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                    .textSelection(.enabled)
                    .padding(.leading, 10)
            } else {
                Text(content)
                    .font(.system(size: 14))
                    .foregroundStyle(ClaudeTheme.textSecondary)
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
        var index = 0

        func flushText() {
            let trimmed = currentText.trimmingTrailingNewlines()
            if !trimmed.isEmpty {
                blocks.append(.text(trimmed))
            }
            currentText = ""
        }

        while index < lines.count {
            let line = lines[index]

            // Code block handling
            if !inCodeBlock && line.hasPrefix("```") {
                flushText()
                inCodeBlock = true
                codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeContent = ""
                index += 1
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
                index += 1
                continue
            }

            // Table detection: check if current line + next two lines form a table
            if let table = parseTable(lines: lines, startIndex: index) {
                flushText()
                blocks.append(.table(headers: table.headers, rows: table.rows))
                index = table.endIndex
                continue
            }

            // Heading
            if let headingMatch = parseHeading(line) {
                flushText()
                blocks.append(.heading(level: headingMatch.level, content: headingMatch.content))
                index += 1
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
                index += 1
                continue
            }

            // Unordered list item
            if let listContent = parseUnorderedListItem(line) {
                flushText()
                blocks.append(.unorderedListItem(content: listContent))
                index += 1
                continue
            }

            // Ordered list item
            if let (number, listContent) = parseOrderedListItem(line) {
                flushText()
                blocks.append(.orderedListItem(number: number, content: listContent))
                index += 1
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
                index += 1
                continue
            }

            // Empty line
            if trimmedLine.isEmpty {
                if !currentText.isEmpty {
                    flushText()
                    blocks.append(.spacer)
                }
                index += 1
                continue
            }

            // Regular text
            if !currentText.isEmpty { currentText += "\n" }
            currentText += line
            index += 1
        }

        // Handle remaining content
        if inCodeBlock && !codeContent.isEmpty {
            blocks.append(.codeBlock(language: codeLanguage, code: codeContent.trimmingTrailingNewlines()))
        } else {
            flushText()
        }

        return blocks
    }

    // MARK: - Table Parsing

    private func parseTable(lines: [String], startIndex: Int) -> (headers: [String], rows: [[String]], endIndex: Int)? {
        guard startIndex + 1 < lines.count else { return nil }

        let headerLine = lines[startIndex]
        let separatorLine = lines[startIndex + 1]

        // Header must contain pipes
        guard headerLine.contains("|") else { return nil }

        // Separator must be like |---|---| or ---|---
        let separatorTrimmed = separatorLine.trimmingCharacters(in: .whitespaces)
        guard isTableSeparator(separatorTrimmed) else { return nil }

        let headers = parseTableRow(headerLine)
        guard !headers.isEmpty else { return nil }

        // Collect data rows
        var rows: [[String]] = []
        var currentIndex = startIndex + 2

        while currentIndex < lines.count {
            let rowLine = lines[currentIndex]
            let trimmed = rowLine.trimmingCharacters(in: .whitespaces)

            // Stop if empty line or non-table line
            guard !trimmed.isEmpty, trimmed.contains("|") else { break }
            // Skip if it's another separator line
            guard !isTableSeparator(trimmed) else {
                currentIndex += 1
                continue
            }

            let cells = parseTableRow(rowLine)
            rows.append(cells)
            currentIndex += 1
        }

        return (headers: headers, rows: rows, endIndex: currentIndex)
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        // Must contain at least one --- pattern and only |, -, :, spaces
        guard stripped.contains("---") else { return false }
        return stripped.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" }
    }

    private func parseTableRow(_ line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        // Remove leading/trailing pipes
        if content.hasPrefix("|") { content = String(content.dropFirst()) }
        if content.hasSuffix("|") { content = String(content.dropLast()) }
        return content.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
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
    case table(headers: [String], rows: [[String]])
    case horizontalRule
    case spacer
}

// MARK: - Table View

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        cellView(text: header, isHeader: true)
                    }
                }
                .background(ClaudeTheme.surfaceTertiary)

                // Separator
                GridRow {
                    Rectangle()
                        .fill(ClaudeTheme.border)
                        .frame(height: 1)
                        .gridCellColumns(headers.count)
                }

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(headers.indices), id: \.self) { colIndex in
                            let text = colIndex < row.count ? row[colIndex] : ""
                            cellView(text: text, isHeader: false)
                        }
                    }
                    .background(rowIndex % 2 == 0 ? Color.clear : ClaudeTheme.surfaceTertiary.opacity(0.4))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
                    .strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
            )
        }
        .padding(.vertical, 4)
    }

    private func cellView(text: String, isHeader: Bool) -> some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
                    .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .textSelection(.enabled)
            } else {
                Text(text)
                    .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                }

                Spacer()

                copyButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ClaudeTheme.codeHeaderBackground)

            Rectangle()
                .fill(ClaudeTheme.border)
                .frame(height: 0.5)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ClaudeTheme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
                .strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
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
            .foregroundStyle(isCopied ? ClaudeTheme.statusSuccess : ClaudeTheme.textTertiary)
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

        | 항목 | 수치 |
        |------|------|
        | Swift 파일 | 381개 |
        | 총 코드 라인 | ~55,000줄 |
        | SwiftUI : UIKit 비율 | 87% : 13% |

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
    .background(ClaudeTheme.background)
}
