import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var showGitHubSheet = false
    @State private var showGitGuide = false

    var body: some View {
        if !appState.onboardingCompleted {
            OnboardingView()
        } else {
            NavigationSplitView {
                sidebarContent
            } detail: {
                detailContent
            }
            .sheet(item: firstPendingPermission) { request in
                PermissionModal(request: request)
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
            // Sidebar toolbar
            HStack(spacing: 8) {
                Button {
                    showGitHubSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image("GitHubMark")
                            .resizable()
                            .frame(width: 16, height: 16)

                        if !appState.isLoggedIn {
                            Text("연동")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .help(appState.isLoggedIn ? "GitHub 레포 관리" : "GitHub 연동")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            ProjectListView()
            Divider()

            // 파일 트리 (프로젝트 선택 시)
            if let project = appState.selectedProject {
                FileTreeView(projectPath: project.path)
                Divider()
            }

            HistoryListView()

            Divider()

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
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .help("Git 기본 개념 배우기")
        }
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
                ContentUnavailableView(
                    "프로젝트를 선택하세요",
                    systemImage: "folder",
                    description: Text("사이드바에서 프로젝트를 선택하거나 새 프로젝트를 추가하세요.")
                )
            }
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

#Preview {
    MainView()
        .environment(AppState())
}
