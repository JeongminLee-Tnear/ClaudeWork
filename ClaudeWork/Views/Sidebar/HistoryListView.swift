import SwiftUI

struct HistoryListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            if sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("히스토리")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .textCase(.uppercase)

            Spacer()

            Button {
                appState.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("새 채팅")
            .disabled(appState.selectedProject == nil)
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List(sessions, selection: selectedSessionBinding) { session in
            sessionRow(session)
                .tag(session.id)
        }
        .listStyle(.sidebar)
    }

    private var selectedSessionBinding: Binding<String?> {
        Binding<String?>(
            get: { appState.currentSession?.id },
            set: { id in
                if let id {
                    appState.selectSession(id: id)
                }
            }
        )
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.title)
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .lineLimit(1)

            Text(formattedDate(session.updatedAt))
                .font(.system(size: 11))
                .foregroundStyle(ClaudeTheme.textTertiary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    await appState.deleteSession(session)
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 20))
                .foregroundStyle(ClaudeTheme.textTertiary)
            Text("채팅 기록이 없습니다")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var sessions: [ChatSession] {
        appState.sessionsForSelectedProject
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    HistoryListView()
        .environment(AppState())
        .frame(width: 260)
}
