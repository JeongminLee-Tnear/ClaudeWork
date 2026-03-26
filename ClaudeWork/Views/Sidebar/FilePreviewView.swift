import SwiftUI

/// File preview with syntax highlighting
struct FilePreviewView: View {
    let filePath: String
    let fileName: String
    @State private var content: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isCopied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ClaudeThemeDivider()

            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let content {
                codeContentView(content)
            }
        }
        .frame(minWidth: 700, idealWidth: 1000, maxWidth: 1200, minHeight: 500, idealHeight: 750, maxHeight: 900)
        .background(ClaudeTheme.background)
        .task { await loadFile() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForExtension)
                .font(.system(size: 14))
                .foregroundStyle(iconColorForExtension)

            Text(fileName)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .lineLimit(1)

            Text(languageLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ClaudeTheme.surfaceSecondary, in: Capsule())

            Spacer()

            if let content {
                let lineCount = content.components(separatedBy: "\n").count
                Text("\(lineCount) lines")
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "copied" : "copy")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(isCopied ? ClaudeTheme.statusSuccess : ClaudeTheme.textTertiary)
                }
                .buttonStyle(.borderless)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(ClaudeTheme.surfaceSecondary, in: Circle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ClaudeTheme.surfacePrimary)
    }

    // MARK: - Content

    private func codeContentView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        let lineNumberWidth = max(String(lines.count).count * 9 + 16, 36)
        let highlighted = SyntaxHighlighter.highlight(text, language: fileExtension)

        return ScrollView([.vertical, .horizontal]) {
            HStack(alignment: .top, spacing: 0) {
                // Line numbers
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                        Text("\(index + 1)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ClaudeTheme.textTertiary.opacity(0.6))
                            .frame(height: 19)
                    }
                }
                .frame(width: CGFloat(lineNumberWidth))
                .padding(.top, 12)
                .padding(.trailing, 8)
                .background(ClaudeTheme.codeBackground.opacity(0.5))

                Rectangle()
                    .fill(ClaudeTheme.border.opacity(0.5))
                    .frame(width: 1)

                // Code content
                Text(highlighted)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ClaudeTheme.codeBackground)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text("loading...")
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(ClaudeTheme.statusWarning)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - File Loading

    private func loadFile() async {
        do {
            let data = try await Task.detached { [filePath] in
                let url = URL(fileURLWithPath: filePath)
                let attr = try FileManager.default.attributesOfItem(atPath: filePath)
                let size = (attr[.size] as? Int) ?? 0
                if size > 1_000_000 {
                    throw FilePreviewError.tooLarge
                }
                return try Data(contentsOf: url)
            }.value

            if let text = String(data: data, encoding: .utf8) {
                content = text
            } else {
                errorMessage = "binary file -- preview unavailable"
            }
        } catch is FilePreviewError {
            errorMessage = "file too large to preview (>1MB)"
        } catch {
            errorMessage = "failed to read: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Helpers

    private var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    private var languageLabel: String {
        switch fileExtension {
        case "swift": return "Swift"
        case "js": return "JavaScript"
        case "jsx": return "JSX"
        case "ts": return "TypeScript"
        case "tsx": return "TSX"
        case "json": return "JSON"
        case "md": return "Markdown"
        case "html": return "HTML"
        case "css": return "CSS"
        case "scss": return "SCSS"
        case "py": return "Python"
        case "rb": return "Ruby"
        case "go": return "Go"
        case "rs": return "Rust"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        case "sh", "bash", "zsh": return "Shell"
        case "sql": return "SQL"
        case "xml": return "XML"
        case "txt": return "Plain Text"
        case "gitignore": return "gitignore"
        case "plist": return "Plist"
        case "entitlements": return "Entitlements"
        case "pbxproj": return "Xcode Project"
        default: return fileExtension.isEmpty ? "File" : fileExtension.uppercased()
        }
    }

    private var iconForExtension: String {
        FileNode(id: "", name: fileName, isDirectory: false, children: []).icon
    }

    private var iconColorForExtension: Color {
        FileNode(id: "", name: fileName, isDirectory: false, children: []).iconColor
    }
}

// MARK: - Error

private enum FilePreviewError: Error {
    case tooLarge
}

// MARK: - Syntax Highlighter

enum SyntaxHighlighter {
    static func highlight(_ code: String, language: String) -> AttributedString {
        var result = AttributedString()
        let tokens = tokenize(code, language: language)

        for token in tokens {
            var attributed = AttributedString(token.text)
            attributed.foregroundColor = color(for: token.kind)
            if token.kind == .keyword || token.kind == .builtinType {
                attributed.font = .system(size: 12, weight: .medium, design: .monospaced)
            }
            result.append(attributed)
        }

        return result
    }

    private static func color(for kind: TokenKind) -> Color {
        switch kind {
        case .keyword:
            return Color(light: .hex(0xAF3A93), dark: .hex(0xFF7AB2))
        case .string:
            return Color(light: .hex(0xC4442D), dark: .hex(0xFF8170))
        case .comment:
            return Color(light: .hex(0x72962A), dark: .hex(0x7EC856))
        case .number:
            return Color(light: .hex(0x1C00CF), dark: .hex(0xD0BF69))
        case .builtinType:
            return Color(light: .hex(0x5B2699), dark: .hex(0xDABAFF))
        case .attribute:
            return Color(light: .hex(0x947100), dark: .hex(0xFFA14F))
        case .property:
            return Color(light: .hex(0x3E6D74), dark: .hex(0x78C2B3))
        case .plain:
            return Color(light: .hex(0x3C3929), dark: .hex(0xCCC9C0))
        }
    }

    // MARK: - Tokenizer

    private static func tokenize(_ code: String, language: String) -> [Token] {
        let lang = languageConfig(for: language)
        var tokens: [Token] = []
        let chars = Array(code)
        var i = 0

        while i < chars.count {
            // Multi-line comment
            if i + 1 < chars.count, chars[i] == "/" && chars[i + 1] == "*" {
                let start = i
                i += 2
                while i + 1 < chars.count, !(chars[i] == "*" && chars[i + 1] == "/") {
                    i += 1
                }
                if i + 1 < chars.count { i += 2 } else { i = chars.count }
                tokens.append(Token(text: String(chars[start..<i]), kind: .comment))
                continue
            }

            // Single-line comment
            if let commentPrefix = lang.lineComment,
               code[code.index(code.startIndex, offsetBy: i)...].hasPrefix(commentPrefix) {
                let start = i
                while i < chars.count, chars[i] != "\n" { i += 1 }
                tokens.append(Token(text: String(chars[start..<i]), kind: .comment))
                continue
            }

            // Hash comment (Python, Shell, YAML)
            if lang.hashComment, chars[i] == "#", (i == 0 || chars[i - 1] == "\n" || chars[i - 1] == " " || chars[i - 1] == "\t") {
                let start = i
                while i < chars.count, chars[i] != "\n" { i += 1 }
                tokens.append(Token(text: String(chars[start..<i]), kind: .comment))
                continue
            }

            // Strings (double-quoted)
            if chars[i] == "\"" {
                // Triple-quoted string
                if i + 2 < chars.count, chars[i + 1] == "\"", chars[i + 2] == "\"" {
                    let start = i
                    i += 3
                    while i + 2 < chars.count, !(chars[i] == "\"" && chars[i + 1] == "\"" && chars[i + 2] == "\"") {
                        if chars[i] == "\\" { i += 1 }
                        i += 1
                    }
                    if i + 2 < chars.count { i += 3 } else { i = chars.count }
                    tokens.append(Token(text: String(chars[start..<i]), kind: .string))
                    continue
                }

                let start = i
                i += 1
                while i < chars.count, chars[i] != "\"", chars[i] != "\n" {
                    if chars[i] == "\\" { i += 1 }
                    i += 1
                }
                if i < chars.count, chars[i] == "\"" { i += 1 }
                tokens.append(Token(text: String(chars[start..<i]), kind: .string))
                continue
            }

            // Strings (single-quoted)
            if chars[i] == "'" {
                let start = i
                i += 1
                while i < chars.count, chars[i] != "'", chars[i] != "\n" {
                    if chars[i] == "\\" { i += 1 }
                    i += 1
                }
                if i < chars.count, chars[i] == "'" { i += 1 }
                tokens.append(Token(text: String(chars[start..<i]), kind: .string))
                continue
            }

            // Attribute (@something)
            if chars[i] == "@" {
                let start = i
                i += 1
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" { i += 1 }
                if i > start + 1 {
                    tokens.append(Token(text: String(chars[start..<i]), kind: .attribute))
                    continue
                }
                tokens.append(Token(text: "@", kind: .plain))
                continue
            }

            // Numbers
            if chars[i].isNumber || (chars[i] == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                let start = i
                if chars[i] == "0", i + 1 < chars.count, (chars[i + 1] == "x" || chars[i + 1] == "b" || chars[i + 1] == "o") {
                    i += 2
                    while i < chars.count, chars[i].isHexDigit || chars[i] == "_" { i += 1 }
                } else {
                    while i < chars.count, chars[i].isNumber || chars[i] == "." || chars[i] == "_" || chars[i] == "e" || chars[i] == "E" { i += 1 }
                }
                tokens.append(Token(text: String(chars[start..<i]), kind: .number))
                continue
            }

            // Identifiers / Keywords
            if chars[i].isLetter || chars[i] == "_" {
                let start = i
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" { i += 1 }
                let word = String(chars[start..<i])
                if lang.keywords.contains(word) {
                    tokens.append(Token(text: word, kind: .keyword))
                } else if lang.types.contains(word) {
                    tokens.append(Token(text: word, kind: .builtinType))
                } else if word.first?.isUppercase == true {
                    tokens.append(Token(text: word, kind: .builtinType))
                } else {
                    // Check if followed by ( -- likely a function
                    if i < chars.count, chars[i] == "(" {
                        tokens.append(Token(text: word, kind: .property))
                    } else {
                        tokens.append(Token(text: word, kind: .plain))
                    }
                }
                continue
            }

            // Everything else
            tokens.append(Token(text: String(chars[i]), kind: .plain))
            i += 1
        }

        return tokens
    }

    private static func languageConfig(for ext: String) -> LanguageConfig {
        switch ext {
        case "swift":
            return LanguageConfig(
                lineComment: "//",
                hashComment: false,
                keywords: swiftKeywords,
                types: swiftTypes
            )
        case "js", "jsx", "ts", "tsx":
            return LanguageConfig(
                lineComment: "//",
                hashComment: false,
                keywords: jsKeywords,
                types: jsTypes
            )
        case "py":
            return LanguageConfig(
                lineComment: nil,
                hashComment: true,
                keywords: pythonKeywords,
                types: pythonTypes
            )
        case "go":
            return LanguageConfig(
                lineComment: "//",
                hashComment: false,
                keywords: goKeywords,
                types: goTypes
            )
        case "rs":
            return LanguageConfig(
                lineComment: "//",
                hashComment: false,
                keywords: rustKeywords,
                types: rustTypes
            )
        case "rb":
            return LanguageConfig(
                lineComment: nil,
                hashComment: true,
                keywords: rubyKeywords,
                types: []
            )
        case "sh", "bash", "zsh":
            return LanguageConfig(
                lineComment: nil,
                hashComment: true,
                keywords: shellKeywords,
                types: []
            )
        case "css", "scss":
            return LanguageConfig(
                lineComment: "//",
                hashComment: false,
                keywords: cssKeywords,
                types: []
            )
        case "html", "xml":
            return LanguageConfig(
                lineComment: nil,
                hashComment: false,
                keywords: htmlKeywords,
                types: []
            )
        case "json":
            return LanguageConfig(
                lineComment: nil,
                hashComment: false,
                keywords: ["true", "false", "null"],
                types: []
            )
        case "yaml", "yml":
            return LanguageConfig(
                lineComment: nil,
                hashComment: true,
                keywords: ["true", "false", "null", "yes", "no"],
                types: []
            )
        case "sql":
            return LanguageConfig(
                lineComment: "--",
                hashComment: false,
                keywords: sqlKeywords,
                types: sqlTypes
            )
        default:
            return LanguageConfig(
                lineComment: "//",
                hashComment: true,
                keywords: [],
                types: []
            )
        }
    }

    // MARK: - Language Definitions

    private static let swiftKeywords: Set<String> = [
        "actor", "associatedtype", "async", "await", "break", "case", "catch", "class",
        "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
        "fallthrough", "fileprivate", "for", "func", "guard", "if", "import", "in",
        "init", "inout", "internal", "is", "let", "nonisolated", "open", "operator",
        "override", "precedencegroup", "private", "protocol", "public", "repeat",
        "rethrows", "return", "self", "some", "static", "struct", "subscript", "super",
        "switch", "throw", "throws", "try", "typealias", "var", "where", "while",
        "true", "false", "nil", "Self", "any", "consuming", "borrowing", "sending",
        "weak", "unowned", "lazy", "mutating", "nonmutating", "convenience", "required",
        "final", "dynamic", "indirect", "isolated",
    ]

    private static let swiftTypes: Set<String> = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
        "Optional", "Result", "Error", "Void", "Any", "AnyObject", "Never",
        "CGFloat", "CGPoint", "CGSize", "CGRect", "URL", "Data", "Date",
        "View", "State", "Binding", "ObservedObject", "Published", "Environment",
        "ObservableObject", "Observable", "Identifiable", "Hashable", "Codable",
        "Equatable", "Comparable", "Sendable", "MainActor", "Task",
    ]

    private static let jsKeywords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue",
        "debugger", "default", "delete", "do", "else", "export", "extends", "false",
        "finally", "for", "from", "function", "if", "import", "in", "instanceof",
        "let", "new", "null", "of", "return", "static", "super", "switch", "this",
        "throw", "true", "try", "typeof", "undefined", "var", "void", "while",
        "with", "yield", "type", "interface", "enum", "implements", "declare",
        "readonly", "abstract", "as", "keyof",
    ]

    private static let jsTypes: Set<String> = [
        "string", "number", "boolean", "object", "symbol", "bigint",
        "Promise", "Map", "Set", "Array", "Object", "Function",
        "Record", "Partial", "Required", "Readonly", "Pick", "Omit",
    ]

    private static let pythonKeywords: Set<String> = [
        "and", "as", "assert", "async", "await", "break", "class", "continue",
        "def", "del", "elif", "else", "except", "finally", "for", "from",
        "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
        "or", "pass", "raise", "return", "try", "while", "with", "yield",
        "True", "False", "None",
    ]

    private static let pythonTypes: Set<String> = [
        "int", "float", "str", "bool", "list", "dict", "set", "tuple",
        "bytes", "type", "object", "Exception",
    ]

    private static let goKeywords: Set<String> = [
        "break", "case", "chan", "const", "continue", "default", "defer",
        "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
        "interface", "map", "package", "range", "return", "select", "struct",
        "switch", "type", "var", "true", "false", "nil",
    ]

    private static let goTypes: Set<String> = [
        "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
        "int", "int8", "int16", "int32", "int64", "rune", "string",
        "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
    ]

    private static let rustKeywords: Set<String> = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn",
        "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
        "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
        "self", "static", "struct", "super", "trait", "true", "type", "unsafe",
        "use", "where", "while",
    ]

    private static let rustTypes: Set<String> = [
        "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
        "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize",
        "String", "Vec", "Box", "Option", "Result", "HashMap", "HashSet",
    ]

    private static let rubyKeywords: Set<String> = [
        "begin", "break", "case", "class", "def", "do", "else", "elsif",
        "end", "ensure", "false", "for", "if", "in", "module", "next",
        "nil", "not", "or", "raise", "rescue", "return", "self", "super",
        "then", "true", "unless", "until", "when", "while", "yield",
        "require", "include", "extend", "attr_accessor", "attr_reader",
    ]

    private static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done",
        "case", "esac", "in", "function", "return", "exit", "local",
        "export", "source", "echo", "read", "set", "unset", "true", "false",
    ]

    private static let cssKeywords: Set<String> = [
        "import", "media", "keyframes", "font-face", "supports", "charset",
        "important", "inherit", "initial", "unset", "none", "auto",
    ]

    private static let htmlKeywords: Set<String> = [
        "html", "head", "body", "div", "span", "p", "a", "img", "ul", "ol",
        "li", "h1", "h2", "h3", "h4", "h5", "h6", "table", "tr", "td",
        "th", "form", "input", "button", "select", "option", "textarea",
        "script", "style", "link", "meta", "title", "section", "article",
        "nav", "header", "footer", "main", "aside",
    ]

    private static let sqlKeywords: Set<String> = [
        "select", "from", "where", "and", "or", "not", "insert", "into",
        "values", "update", "set", "delete", "create", "table", "alter",
        "drop", "index", "join", "inner", "left", "right", "outer", "on",
        "group", "by", "order", "having", "limit", "offset", "as", "null",
        "is", "in", "between", "like", "exists", "case", "when", "then",
        "else", "end", "distinct", "union", "all", "primary", "key",
        "foreign", "references", "default", "constraint", "true", "false",
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "INSERT", "INTO",
        "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "ALTER",
        "DROP", "INDEX", "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "ON",
        "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "AS", "NULL",
        "IS", "IN", "BETWEEN", "LIKE", "EXISTS", "CASE", "WHEN", "THEN",
        "ELSE", "END", "DISTINCT", "UNION", "ALL", "PRIMARY", "KEY",
        "FOREIGN", "REFERENCES", "DEFAULT", "CONSTRAINT", "TRUE", "FALSE",
    ]

    private static let sqlTypes: Set<String> = [
        "int", "integer", "varchar", "text", "boolean", "date", "timestamp",
        "float", "double", "decimal", "char", "blob", "serial", "bigint",
        "INT", "INTEGER", "VARCHAR", "TEXT", "BOOLEAN", "DATE", "TIMESTAMP",
        "FLOAT", "DOUBLE", "DECIMAL", "CHAR", "BLOB", "SERIAL", "BIGINT",
    ]
}

// MARK: - Token Types

private struct Token {
    let text: String
    let kind: TokenKind
}

private enum TokenKind {
    case keyword, string, comment, number, builtinType, attribute, property, plain
}

private struct LanguageConfig {
    let lineComment: String?
    let hashComment: Bool
    let keywords: Set<String>
    let types: Set<String>
}

#Preview {
    FilePreviewView(
        filePath: "/Users/jmlee/workspace/ClaudeWork/ClaudeWork/Views/Sidebar/FileTreeView.swift",
        fileName: "FileTreeView.swift"
    )
}
