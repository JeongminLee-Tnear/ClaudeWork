import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var isCheckingCLI = false
    @State private var cliInstalled = false
    @State private var cliVersion: String?
    @State private var cliError: String?

    private let totalSteps = 2

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
        .frame(width: 560, height: 440)
        .task {
            await checkCLI()
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color(nsColor: .separatorColor))
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
                .foregroundStyle(.secondary)

            Text("Claude CLI 설치 확인")
                .font(.title2)
                .fontWeight(.semibold)

            if isCheckingCLI {
                ProgressView("확인 중...")
            } else if cliInstalled {
                Label("설치됨 — \(cliVersion ?? "")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else {
                VStack(spacing: 12) {
                    Label("Claude CLI를 찾을 수 없습니다", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.body)

                    if let error = cliError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("설치 명령어:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("npm install -g @anthropic-ai/claude-code")
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    "npm install -g @anthropic-ai/claude-code",
                                    forType: .string
                                )
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("복사")
                        }
                    }
                }

                Button("다시 확인") {
                    Task { await checkCLI() }
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Step 2: GitHub

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
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button("다음") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 0 && !cliInstalled)
            } else {
                Button("시작하기") {
                    appState.onboardingCompleted = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Helpers

    private func checkCLI() async {
        isCheckingCLI = true
        cliError = nil

        // Use the shared ClaudeService from AppState
        do {
            let version = try await appState.claude.checkVersion()
            cliVersion = version
            cliInstalled = true
            appState.claudeInstalled = true
        } catch {
            cliInstalled = false
            cliError = error.localizedDescription

            // Also log the candidate paths for debugging
            let binary = await appState.claude.findClaudeBinary()
            if let binary {
                cliError = "바이너리 발견: \(binary), 하지만 버전 체크 실패"
                cliInstalled = true
                appState.claudeInstalled = true
            }
        }

        isCheckingCLI = false
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
