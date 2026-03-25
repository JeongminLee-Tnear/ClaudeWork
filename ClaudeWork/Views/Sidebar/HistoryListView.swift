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
                .font(.headline)

            Spacer()

            Button {
                appState.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
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
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(.body)
                .lineLimit(1)

            Text(formattedDate(session.updatedAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("채팅 기록이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
