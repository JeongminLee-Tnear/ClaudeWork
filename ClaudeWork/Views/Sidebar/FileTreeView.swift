import SwiftUI

/// 프로젝트 폴더 구조를 트리 형태로 보여주는 뷰.
struct FileTreeView: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var rootNode: FileNode?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("파일")
                    .font(.headline)

                Spacer()

                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("새로고침")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let root = rootNode {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(root.children) { child in
                            FileNodeRow(node: child, depth: 0)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                VStack {
                    Spacer()
                    Text("파일을 불러올 수 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { reload() }
        .onChange(of: projectPath) { _, _ in reload() }
        .onChange(of: appState.isStreaming) { old, new in
            // 스트리밍 완료 시 파일 트리 자동 새로고침
            if old && !new { reload() }
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

// MARK: - File Node Row

private struct FileNodeRow: View {
    let node: FileNode
    let depth: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    // 들여쓰기
                    Spacer()
                        .frame(width: CGFloat(depth) * 16)

                    // 폴더 화살표
                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .frame(width: 10)
                    } else {
                        Spacer()
                            .frame(width: 10)
                    }

                    // 아이콘
                    Image(systemName: node.icon)
                        .font(.caption)
                        .foregroundStyle(node.iconColor)
                        .frame(width: 16)

                    // 이름
                    Text(node.name)
                        .font(.system(size: 13, design: node.isDirectory ? .default : .monospaced))
                        .foregroundStyle(node.isDirectory ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    // 파일 수 (폴더)
                    if node.isDirectory {
                        Text("\(node.children.count)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Children
            if isExpanded {
                ForEach(node.children) { child in
                    FileNodeRow(node: child, depth: depth + 1)
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

    /// 파일 확장자 기반 아이콘
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
        if isDirectory { return .accentColor }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "json": return .green
        case "css", "scss": return .pink
        case "html": return .red
        case "png", "jpg", "jpeg", "svg", "pdf": return .purple
        default: return .secondary
        }
    }

    /// 디렉토리를 스캔해서 FileNode 트리를 생성
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
                    // 폴더 우선, 이름순
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
