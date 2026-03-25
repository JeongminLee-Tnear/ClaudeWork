import SwiftUI

struct GitHubSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showLoginSheet = false
    @State private var searchText = ""
    @State private var cloningRepo: String?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("GitHub")
                    .font(.headline)

                Spacer()

                if appState.isLoggedIn, let user = appState.gitHubUser {
                    Text("@\(user.login)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await appState.fetchRepos() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .help("새로고침")
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if appState.isLoggedIn {
                repoContent
            } else {
                connectPrompt
            }
        }
        .frame(width: 480, height: 520)
        .focusable(false)
        .task {
            if appState.isLoggedIn, appState.repos.isEmpty {
                await appState.fetchRepos()
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            GitHubLoginView()
        }
    }

    // MARK: - Connect Prompt

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("GitHub에 연결하면\n레포를 바로 가져올 수 있어요")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showLoginSheet = true
            } label: {
                Label("GitHub 연동", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Repo Content

    private var repoContent: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("레포 검색...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if appState.isFetchingRepos {
                loadingState
            } else if appState.repos.isEmpty {
                emptyState
            } else {
                repoListContent
            }

            Divider()

            // Footer
            HStack {
                Link("조직 레포가 안 보이나요? →",
                     destination: URL(string: "https://github.com/settings/connections/applications/\(GitHubService.oauthClientId)")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text("레포를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("레포가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var repoListContent: some View {
        List(filteredRepos) { repo in
            repoRow(repo)
        }
        .listStyle(.plain)
    }

    private func repoRow(_ repo: GitHubRepo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.body)
                    .lineLimit(1)
                Text(repo.fullName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if cloningRepo == repo.fullName {
                ProgressView()
                    .controlSize(.small)
            } else if isAlreadyAdded(repo) {
                Label("추가됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await cloneRepo(repo) }
                } label: {
                    Label("추가", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private var filteredRepos: [GitHubRepo] {
        if searchText.isEmpty {
            return appState.repos
        }
        return appState.repos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func isAlreadyAdded(_ repo: GitHubRepo) -> Bool {
        appState.projects.contains { $0.gitHubRepo == repo.fullName }
    }

    private func cloneRepo(_ repo: GitHubRepo) async {
        cloningRepo = repo.fullName
        do {
            try await appState.cloneAndAddProject(repo)
        } catch {
            appState.errorMessage = "Clone 실패: \(error.localizedDescription)"
            appState.showError = true
        }
        cloningRepo = nil
    }
}

#Preview {
    GitHubSheet()
        .environment(AppState())
}
