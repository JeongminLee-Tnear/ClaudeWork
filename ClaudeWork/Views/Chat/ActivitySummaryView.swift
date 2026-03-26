import SwiftUI

/// Claude가 수행한 작업을 시각적으로 요약해주는 패널.
/// 비개발자가 "무슨 일이 일어났는지" 한눈에 파악할 수 있도록 한다.
struct ActivitySummaryView: View {
    let messages: [ChatMessage]
    @State private var isExpanded = true

    var body: some View {
        if !activities.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(activities) { activity in
                        activityRow(activity)
                    }
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.clipboard")
                        .foregroundStyle(ClaudeTheme.accent)
                    Text("작업 요약")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                    Text("(\(activities.count)개)")
                        .font(.system(size: 11))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                }
            }
            .padding(12)
            .background(ClaudeTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                    .strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Activity Row

    private func activityRow(_ activity: Activity) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(activity.icon)
                .font(.body)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textPrimary)

                Text(activity.description)
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if activity.hasError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ClaudeTheme.statusWarning)
                    .font(.caption)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Activity Extraction

    private var activities: [Activity] {
        messages
            .filter { $0.role == .assistant }
            .flatMap { message in
                message.toolCalls.compactMap { toolCall -> Activity? in
                    guard toolCall.result != nil else { return nil }
                    return Activity(from: toolCall)
                }
            }
    }
}

// MARK: - Activity Model

struct Activity: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let hasError: Bool

    init?(from toolCall: ToolCall) {
        self.id = toolCall.id
        self.hasError = toolCall.isError

        switch toolCall.name.lowercased() {
        case "read":
            self.icon = "📖"
            self.title = "파일 읽기"
            let path = toolCall.input["file_path"]?.stringValue ?? "알 수 없는 파일"
            self.description = "\(Activity.fileName(from: path)) 파일의 내용을 확인했어요"

        case "edit":
            self.icon = "✏️"
            self.title = "파일 수정"
            let path = toolCall.input["file_path"]?.stringValue ?? "알 수 없는 파일"
            self.description = "\(Activity.fileName(from: path)) 파일을 수정했어요"

        case "write":
            self.icon = "📝"
            self.title = "파일 생성"
            let path = toolCall.input["file_path"]?.stringValue ?? "알 수 없는 파일"
            self.description = "\(Activity.fileName(from: path)) 파일을 새로 만들었어요"

        case "bash":
            self.icon = "⚡"
            self.title = "명령어 실행"
            let command = toolCall.input["command"]?.stringValue ?? ""
            self.description = Activity.describeCommand(command)

        case "glob":
            self.icon = "🔍"
            self.title = "파일 찾기"
            let pattern = toolCall.input["pattern"]?.stringValue ?? ""
            self.description = "'\(pattern)' 패턴으로 파일을 찾았어요"

        case "grep":
            self.icon = "🔎"
            self.title = "내용 검색"
            let pattern = toolCall.input["pattern"]?.stringValue ?? ""
            self.description = "코드에서 '\(pattern)'을(를) 검색했어요"

        default:
            self.icon = "🔧"
            self.title = toolCall.name
            self.description = "도구를 실행했어요"
        }
    }

    private static func fileName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private static func describeCommand(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("npm install") || trimmed.hasPrefix("yarn add") {
            return "필요한 패키지를 설치했어요"
        }
        if trimmed.hasPrefix("npm run build") || trimmed.hasPrefix("swift build") || trimmed.hasPrefix("xcodebuild") {
            return "프로젝트를 빌드했어요"
        }
        if trimmed.hasPrefix("npm test") || trimmed.hasPrefix("swift test") || trimmed.hasPrefix("pytest") {
            return "테스트를 실행했어요"
        }
        if trimmed.hasPrefix("npm run dev") || trimmed.hasPrefix("npm start") {
            return "개발 서버를 시작했어요"
        }
        if trimmed.hasPrefix("git ") {
            return describeGitCommand(trimmed)
        }
        if trimmed.hasPrefix("mkdir") {
            return "폴더를 만들었어요"
        }
        if trimmed.hasPrefix("ls") || trimmed.hasPrefix("find") {
            return "파일 목록을 확인했어요"
        }
        if trimmed.hasPrefix("cat") || trimmed.hasPrefix("head") || trimmed.hasPrefix("tail") {
            return "파일 내용을 확인했어요"
        }

        if trimmed.count > 60 {
            return String(trimmed.prefix(60)) + "..."
        }
        return trimmed
    }

    private static func describeGitCommand(_ command: String) -> String {
        if command.contains("commit") { return "변경사항을 저장(커밋)했어요" }
        if command.contains("push") { return "변경사항을 서버에 올렸어요" }
        if command.contains("pull") { return "서버에서 최신 코드를 받았어요" }
        if command.contains("checkout") || command.contains("switch") { return "작업 브랜치를 변경했어요" }
        if command.contains("branch") { return "브랜치(작업 사본)를 만들었어요" }
        if command.contains("status") { return "현재 상태를 확인했어요" }
        if command.contains("log") { return "작업 히스토리를 확인했어요" }
        if command.contains("add") { return "변경한 파일을 저장 준비했어요" }
        if command.contains("clone") { return "프로젝트를 복사해왔어요" }
        return "Git 작업을 수행했어요"
    }
}

#Preview {
    ActivitySummaryView(messages: [
        ChatMessage(role: .assistant, toolCalls: [
            ToolCall(id: "1", name: "Read", input: ["file_path": JSONValue.string("/src/App.swift")], result: "contents", isError: false),
            ToolCall(id: "2", name: "Edit", input: ["file_path": JSONValue.string("/src/App.swift")], result: "ok", isError: false),
            ToolCall(id: "3", name: "Bash", input: ["command": JSONValue.string("npm install react")], result: "ok", isError: false),
            ToolCall(id: "4", name: "Bash", input: ["command": JSONValue.string("git commit -m 'fix'")], result: "ok", isError: false),
        ]),
    ])
    .padding()
    .frame(width: 400)
    .background(ClaudeTheme.background)
}
