import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var isCheckingCLI = false
    @State private var cliInstalled = false
    @State private var cliVersion: String?
    @State private var cliError: String?

    // Setup state
    @State private var toolStatus: SetupService.ToolStatus?
    @State private var isCheckingTools = false
    @State private var isInstallingTools = false
    @State private var setupError: String?

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            progressIndicator
                .padding(.top, 24)

            Spacer()

            // Step content
            Group {
                switch currentStep {
                case 0:
                    cliCheckStep
                case 1:
                    toolSetupStep
                case 2:
                    githubStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: 460)

            Spacer()

            // Navigation
            navigationButtons
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 560, height: 500)
        .background(ClaudeTheme.background)
        .task {
            await checkCLI()
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? ClaudeTheme.accent : ClaudeTheme.border)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: 200)
    }

    // MARK: - Step 1: CLI Check

    private var cliCheckStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(ClaudeTheme.accent)

            Text("Claude CLI 설치 확인")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudeTheme.textPrimary)

            if isCheckingCLI {
                ProgressView("확인 중...")
            } else if cliInstalled {
                Label("설치됨 — \(cliVersion ?? "")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                    .font(.body)
            } else {
                VStack(spacing: 12) {
                    Label("Claude CLI를 찾을 수 없습니다", systemImage: "xmark.circle.fill")
                        .foregroundStyle(ClaudeTheme.statusError)
                        .font(.body)

                    if let error = cliError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(ClaudeTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("설치 명령어:")
                            .font(.subheadline)
                            .foregroundStyle(ClaudeTheme.textSecondary)

                        HStack {
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(ClaudeTheme.textPrimary)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(ClaudeTheme.codeBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    "npm install -g @anthropic-ai/claude-code",
                                    forType: .string
                                )
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                            }
                            .buttonStyle(.borderless)
                            .help("복사")
                        }
                    }
                }

                Button("다시 확인") {
                    Task { await checkCLI() }
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Step 2: Tool Setup

    private var toolSetupStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundStyle(ClaudeTheme.accent)

            Text("개발 도구 설정")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ClaudeTheme.textPrimary)

            Text("필요한 도구들을 확인하고 설치합니다.")
                .font(.subheadline)
                .foregroundStyle(ClaudeTheme.textSecondary)

            if isCheckingTools {
                ProgressView("도구 확인 중...")
            } else if let status = toolStatus {
                VStack(alignment: .leading, spacing: 10) {
                    toolStatusRow("gstack (QA/브라우징)", installed: status.gstackInstalled)
                    toolStatusRow("Commands (start/submit/cancel)", installed: status.commandsInstalled)
                    toolStatusRow("Git Workflow 스킬", installed: status.gitWorkflowInstalled)
                }
                .padding(16)
                .background(ClaudeTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))

                if status.allInstalled {
                    Label("모든 도구가 설치되었습니다", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(ClaudeTheme.statusSuccess)
                        .font(.body)
                } else {
                    if isInstallingTools {
                        ProgressView("설치 중...")
                    } else {
                        Button("누락된 도구 설치") {
                            Task { await installMissingTools() }
                        }
                        .buttonStyle(ClaudeAccentButtonStyle())
                    }
                }

                if let error = setupError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(ClaudeTheme.statusError)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .task {
            await checkTools()
        }
    }

    private func toolStatusRow(_ name: String, installed: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(installed ? ClaudeTheme.statusSuccess : ClaudeTheme.statusError)
                .font(.system(size: 14))

            Text(name)
                .font(.subheadline)
                .foregroundStyle(ClaudeTheme.textPrimary)

            Spacer()

            Text(installed ? "설치됨" : "미설치")
                .font(.caption)
                .foregroundStyle(installed ? ClaudeTheme.statusSuccess : ClaudeTheme.textTertiary)
        }
    }

    // MARK: - Step 3: GitHub

    private var githubStep: some View {
        GitHubLoginView()
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("이전") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(ClaudeSecondaryButtonStyle())
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button("다음") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(ClaudeAccentButtonStyle())
                .disabled(!canAdvance)
            } else {
                Button("시작하기") {
                    appState.skipGitHubLogin()
                }
                .buttonStyle(ClaudeAccentButtonStyle())
            }
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0:
            return cliInstalled
        case 1:
            return toolStatus?.allInstalled ?? false
        default:
            return true
        }
    }

    // MARK: - Helpers

    private func checkCLI() async {
        isCheckingCLI = true
        cliError = nil

        do {
            let version = try await appState.claude.checkVersion()
            cliVersion = version
            cliInstalled = true
            appState.claudeInstalled = true
        } catch {
            cliInstalled = false
            cliError = error.localizedDescription

            let binary = await appState.claude.findClaudeBinary()
            if let binary {
                cliError = "바이너리 발견: \(binary), 하지만 버전 체크 실패"
                cliInstalled = true
                appState.claudeInstalled = true
            }
        }

        isCheckingCLI = false
    }

    private func checkTools() async {
        isCheckingTools = true
        setupError = nil
        toolStatus = await appState.setup.checkAllTools()
        isCheckingTools = false
    }

    private func installMissingTools() async {
        guard let status = toolStatus else { return }
        isInstallingTools = true
        setupError = nil

        do {
            toolStatus = try await appState.setup.installMissing(status: status)
        } catch {
            setupError = error.localizedDescription
        }

        isInstallingTools = false
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
