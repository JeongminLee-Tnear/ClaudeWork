import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var showGitHubSheet = false
    @State private var showGitGuide = false
    @State private var showFilePicker = false

    var body: some View {
        if !appState.onboardingCompleted {
            OnboardingView()
        } else {
            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .navigationTitle("")
            .toolbar(removing: .title)
            .sheet(item: firstPendingPermission) { request in
                PermissionModal(request: request)
            }
            .sheet(isPresented: Bindable(appState).showRoleSelection) {
                RoleSelectionSheet()
            }
            .alert("오류", isPresented: Bindable(appState).showError) {
                Button("확인") { }
            } message: {
                Text(appState.errorMessage ?? "알 수 없는 오류")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Sidebar toolbar: GitHub + Project Menu + Add
            HStack(spacing: 8) {
                Button {
                    showGitHubSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image("GitHubMark")
                            .resizable()
                            .frame(width: 20, height: 20)

                        if !appState.isLoggedIn {
                            Text("연동")
                                .font(.caption)
                                .foregroundStyle(ClaudeTheme.textSecondary)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .help(appState.isLoggedIn ? "GitHub 레포 관리" : "GitHub 연동")

                // 프로젝트 선택 메뉴
                Menu {
                    ForEach(appState.projects) { project in
                        Button {
                            Task { await appState.selectProject(project) }
                        } label: {
                            HStack {
                                Text(project.name)
                                if appState.selectedProject?.id == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    if appState.projects.isEmpty {
                        Text("프로젝트 없음")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ClaudeTheme.accent)
                        Text(appState.selectedProject?.name ?? "프로젝트 선택")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ClaudeTheme.textPrimary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ClaudeTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // 프로젝트 추가 버튼
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(ClaudeTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 6))
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

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ClaudeThemeDivider()

            // 파일 트리 (프로젝트 선택 시)
            if let project = appState.selectedProject {
                FileTreeView(projectPath: project.path)
                ClaudeThemeDivider()
            }

            HistoryListView()

            ClaudeThemeDivider()

            // Git 상태 표시
            if let project = appState.selectedProject {
                GitStatusView(projectPath: project.path)
            }

            // Git 가이드 버튼
            Button {
                showGitGuide = true
            } label: {
                Label("Git 가이드", systemImage: "book.fill")
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .help("Git 기본 개념 배우기")
        }
        .background(ClaudeTheme.sidebarBackground)
        .sheet(isPresented: $showGitGuide) {
            GitGuideView()
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        .sheet(isPresented: $showGitHubSheet) {
            GitHubSheet()
        }
    }

    // MARK: - Detail

    private var detailContent: some View {
        Group {
            if appState.selectedProject != nil {
                ChatView()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 48))
                        .foregroundStyle(ClaudeTheme.accent)

                    Text("프로젝트를 선택하세요")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ClaudeTheme.textPrimary)

                    Text("사이드바에서 프로젝트를 선택하거나 새 프로젝트를 추가하세요.")
                        .font(.subheadline)
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ClaudeTheme.background)
            }
        }
    }

    // MARK: - Folder Selection

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }

        Task {
            await appState.addProjectFromFolder(url)
        }
    }

    // MARK: - Permission Binding

    private var firstPendingPermission: Binding<PermissionRequest?> {
        Binding<PermissionRequest?>(
            get: { appState.pendingPermissions.first },
            set: { _ in }
        )
    }
}

// MARK: - Claude Theme Divider

struct ClaudeThemeDivider: View {
    var body: some View {
        Rectangle()
            .fill(ClaudeTheme.borderSubtle)
            .frame(height: 1)
    }
}

// MARK: - Role Selection Sheet

struct RoleSelectionSheet: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 40))
                .foregroundStyle(ClaudeTheme.accent)

            Text("프로젝트 역할 선택")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudeTheme.textPrimary)

            if let url = appState.pendingRoleProjectURL {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }

            Text("이 프로젝트에서 수행할 역할을 선택하세요.")
                .font(.subheadline)
                .foregroundStyle(ClaudeTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(ProjectRole.allCases, id: \.self) { role in
                    Button {
                        Task { await appState.completeRoleSelection(role) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: role.icon)
                                .font(.system(size: 20))
                                .frame(width: 32)
                                .foregroundStyle(ClaudeTheme.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ClaudeTheme.textPrimary)

                                Text(role.description)
                                    .font(.caption)
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(ClaudeTheme.textTertiary)
                        }
                        .padding(12)
                        .background(ClaudeTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("취소") {
                appState.cancelRoleSelection()
            }
            .buttonStyle(ClaudeSecondaryButtonStyle())
        }
        .padding(24)
        .frame(width: 400)
        .background(ClaudeTheme.background)
    }
}

#Preview {
    MainView()
        .environment(AppState())
}
