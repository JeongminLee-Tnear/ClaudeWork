import SwiftUI

/// 프로젝트 폴더 구조를 트리 형태로 보여주는 뷰.
struct FileTreeView: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var rootNode: FileNode?
    @State private var isLoading = true
    @State private var previewFile: PreviewFile?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("파일")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("새로고침")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ClaudeThemeDivider()

            if isLoading {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("불러오는 중...")
                        .font(.system(size: 12))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let root = rootNode {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(root.children) { child in
                            FileNodeRow(node: child, depth: 0, onFileSelect: { node in
                                previewFile = PreviewFile(path: node.id, name: node.name)
                            })
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Text("파일을 불러올 수 없어요")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { reload() }
        .onChange(of: projectPath) { _, _ in reload() }
        .onChange(of: appState.isStreaming) { old, new in
            if old && !new { reload() }
        }
        .sheet(item: $previewFile) { file in
            FilePreviewView(filePath: file.path, fileName: file.name)
        }
    }

    private func reload() {
        isLoading = true
        Task.detached { [projectPath] in
            let node = FileNode.scan(path: projectPath, maxDepth: 4)
            await MainActor.run {
                rootNode = node
                isLoading = false
            }
        }
    }
}

// MARK: - Preview File Model

struct PreviewFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
}

// MARK: - File Node Row

private struct FileNodeRow: View {
    let node: FileNode
    let depth: Int
    let onFileSelect: (FileNode) -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    onFileSelect(node)
                }
            } label: {
                HStack(spacing: 4) {
                    Spacer()
                        .frame(width: CGFloat(depth) * 16)

                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                            .frame(width: 10)
                    } else {
                        Spacer()
                            .frame(width: 10)
                    }

                    Image(systemName: node.icon)
                        .font(.caption)
                        .foregroundStyle(node.isDirectory ? ClaudeTheme.accent : node.iconColor)
                        .frame(width: 16)

                    Text(node.name)
                        .font(.system(size: 12, design: node.isDirectory ? .default : .monospaced))
                        .foregroundStyle(node.isDirectory ? ClaudeTheme.textPrimary : ClaudeTheme.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if node.isDirectory {
                        Text("\(node.children.count)")
                            .font(.system(size: 9))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(isHovered && !node.isDirectory ? ClaudeTheme.sidebarItemHover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }

            if isExpanded {
                ForEach(node.children) { child in
                    FileNodeRow(node: child, depth: depth + 1, onFileSelect: onFileSelect)
                }
            }
        }
    }
}

// MARK: - File Node Model

struct FileNode: Identifiable, Sendable {
    let id: String
    let name: String
    let isDirectory: Bool
    let children: [FileNode]

    var icon: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "json": return "curlybraces"
        case "md", "txt": return "doc.text"
        case "png", "jpg", "jpeg", "svg", "pdf": return "photo"
        case "css", "scss": return "paintbrush"
        case "html": return "globe"
        case "yaml", "yml", "toml": return "gearshape"
        case "gitignore": return "eye.slash"
        case "xcodeproj", "xcworkspace": return "hammer"
        default: return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory { return ClaudeTheme.accent }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "json": return ClaudeTheme.statusSuccess
        case "css", "scss": return .pink
        case "html": return ClaudeTheme.statusError
        case "png", "jpg", "jpeg", "svg", "pdf": return .purple
        default: return ClaudeTheme.textTertiary
        }
    }

    static func scan(path: String, maxDepth: Int) -> FileNode? {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        return buildNode(url: url, fm: fm, currentDepth: 0, maxDepth: maxDepth)
    }

    private static let ignoredNames: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData",
        "node_modules", ".DS_Store", "Pods",
        "xcuserdata", ".xcodeproj", ".xcworkspace",
    ]

    private static func buildNode(
        url: URL,
        fm: FileManager,
        currentDepth: Int,
        maxDepth: Int
    ) -> FileNode {
        let name = url.lastPathComponent

        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)

        guard isDir.boolValue else {
            return FileNode(id: url.path, name: name, isDirectory: false, children: [])
        }

        var children: [FileNode] = []

        if currentDepth < maxDepth {
            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            children = contents
                .filter { !ignoredNames.contains($0.lastPathComponent) }
                .map { buildNode(url: $0, fm: fm, currentDepth: currentDepth + 1, maxDepth: maxDepth) }
                .sorted { lhs, rhs in
                    if lhs.isDirectory != rhs.isDirectory {
                        return lhs.isDirectory
                    }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
        }

        return FileNode(id: url.path, name: name, isDirectory: true, children: children)
    }
}

#Preview {
    FileTreeView(projectPath: "/Users/jmlee/workspace/ClaudeWork")
        .frame(width: 280, height: 400)
}
