import SwiftUI
import UniformTypeIdentifiers

struct ProjectListView: View {
    @Environment(AppState.self) private var appState
    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            List(appState.projects, selection: selectedProjectBinding) { project in
                projectRow(project)
                    .tag(project.id)
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("프로젝트")
                .font(.headline)

            Spacer()

            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("프로젝트 추가")
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
        }
    }

    // MARK: - Project Row

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)
                    .lineLimit(1)

                Text(truncatedPath(project.path))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var selectedProjectBinding: Binding<UUID?> {
        Binding<UUID?>(
            get: { appState.selectedProject?.id },
            set: { id in
                if let id,
                   let project = appState.projects.first(where: { $0.id == id }) {
                    Task { await appState.selectProject(project) }
                }
            }
        )
    }

    private static let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    private func truncatedPath(_ path: String) -> String {
        if path.hasPrefix(Self.homePath) {
            return "~" + path.dropFirst(Self.homePath.count)
        }
        return path
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }

        Task {
            await appState.addProjectFromFolder(url)
        }
    }
}

#Preview {
    ProjectListView()
        .environment(AppState())
        .frame(width: 260)
}
