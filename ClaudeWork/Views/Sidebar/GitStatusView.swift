import SwiftUI

/// 프로젝트의 Git 상태를 시각적으로 보여주는 뷰.
struct GitStatusView: View {
    let projectPath: String
    @Environment(AppState.self) private var appState
    @State private var gitStatus: GitStatusInfo = .loading
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            switch gitStatus {
            case .loading:
                ProgressView()
                    .controlSize(.mini)
                Text("확인 중...")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)

            case .notARepo:
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                Text("Git 프로젝트가 아님")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)

            case .clean(let branch):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                Text(branch)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text("변경 없음")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textSecondary)

            case .dirty(let branch, let changes):
                Circle()
                    .fill(ClaudeTheme.accent)
                    .frame(width: 6, height: 6)
                Text(branch)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text("\(changes.total)개 변경")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.accent)

                if changes.modified > 0 {
                    badge("수정 \(changes.modified)", color: .blue)
                }
                if changes.added > 0 {
                    badge("추가 \(changes.added)", color: ClaudeTheme.statusSuccess)
                }
                if changes.deleted > 0 {
                    badge("삭제 \(changes.deleted)", color: ClaudeTheme.statusError)
                }

            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                Text("상태 확인 실패")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }

            Spacer()

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }
            .buttonStyle(.borderless)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ClaudeTheme.surfaceSecondary.opacity(0.5))
        .onAppear { refresh() }
        .onChange(of: projectPath) { _, _ in refresh() }
        .onChange(of: appState.isStreaming) { old, new in
            if old && !new { refresh() }
        }
    }

    // MARK: - Badge

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Refresh

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            gitStatus = .loading
            gitStatus = await fetchGitStatus(at: projectPath)
        }
    }
}

// MARK: - Git Status Model

enum GitStatusInfo: Sendable {
    case loading
    case notARepo
    case clean(branch: String)
    case dirty(branch: String, changes: ChangeCount)
    case error

    struct ChangeCount: Sendable {
        let modified: Int
        let added: Int
        let deleted: Int
        var total: Int { modified + added + deleted }
    }
}

// MARK: - Git Status Fetcher

private func fetchGitStatus(at path: String) async -> GitStatusInfo {
    guard let branchResult = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: path),
          !branchResult.isEmpty else {
        return .notARepo
    }

    let branch = branchResult.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let statusResult = await runGit(["status", "--porcelain"], at: path) else {
        return .error
    }

    if statusResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .clean(branch: branch)
    }

    let lines = statusResult.components(separatedBy: "\n").filter { !$0.isEmpty }
    var modified = 0
    var added = 0
    var deleted = 0

    for line in lines {
        guard line.count >= 2 else { continue }
        let index = line.index(line.startIndex, offsetBy: 1)
        let statusChar = line[index]
        switch statusChar {
        case "M": modified += 1
        case "A", "?": added += 1
        case "D": deleted += 1
        default: modified += 1
        }
    }

    return .dirty(
        branch: branch,
        changes: .init(modified: modified, added: added, deleted: deleted)
    )
}

private func runGit(_ args: [String], at path: String) async -> String? {
    await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil as String?
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }.value
}

#Preview {
    VStack(spacing: 0) {
        GitStatusView(projectPath: "/Users/jmlee/workspace/ClaudeWork")
    }
    .frame(width: 400)
}
