import SwiftUI

/// 프로젝트의 Git 상태를 시각적으로 보여주는 뷰.
/// 현재 브랜치, 변경된 파일 수, 상태를 색상과 아이콘으로 표시한다.
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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

            case .notARepo:
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Git 프로젝트가 아님")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

            case .clean(let branch):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text(branch)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                Text("변경 없음")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

            case .dirty(let branch, let changes):
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.orange)
                Text(branch)
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                Text("\(changes.total)개 변경")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)

                // 변경 종류별 배지
                if changes.modified > 0 {
                    badge("수정 \(changes.modified)", color: .blue)
                }
                if changes.added > 0 {
                    badge("추가 \(changes.added)", color: .green)
                }
                if changes.deleted > 0 {
                    badge("삭제 \(changes.deleted)", color: .red)
                }

            case .error:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("상태 확인 실패")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Refresh button
            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onAppear { refresh() }
        .onChange(of: projectPath) { _, _ in refresh() }
        .onChange(of: appState.isStreaming) { old, new in
            // 스트리밍 완료 시 자동 새로고침
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
    // Check if it's a git repo
    guard let branchResult = await runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: path),
          !branchResult.isEmpty else {
        return .notARepo
    }

    let branch = branchResult.trimmingCharacters(in: .whitespacesAndNewlines)

    // Get status
    guard let statusResult = await runGit(["status", "--porcelain"], at: path) else {
        return .error
    }

    if statusResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .clean(branch: branch)
    }

    // Parse status
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

        // 먼저 데이터를 읽고 나서 종료 대기 (파이프 버퍼 교착 방지)
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
