import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var isInputFocused: Bool
    @State private var inputText = ""
    @State private var showStartInput = false
    @State private var startDescription = ""
    @State private var showStartResponse = false

    var body: some View {
        VStack(spacing: 0) {
            toolbarArea

            Divider()

            messageScrollView

            Divider()

            inputBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            // /start 응답 팝업
            if showStartResponse {
                startResponseOverlay
            }
        }
        .onChange(of: appState.isStreaming) { old, new in
            // Start 모드에서 스트리밍 완료 시 → 마지막 문장 복사 후 새 세션
            if old && !new && appState.isStartMode {
                handleStartCompletion()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarArea: some View {
        HStack {
            if let project = appState.selectedProject {
                Label(project.name, systemImage: "folder.fill")
                    .font(.headline)
            }

            Spacer()

            if let version = appState.claudeVersion {
                Text("CLI \(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: Bindable(appState).selectedModel) {
                ForEach(AppState.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Button {
                showStartInput = true
                startDescription = ""
            } label: {
                Text("시작")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(appState.isStreaming)
            .help("/start 명령 실행")

            Button {
                Task { await appState.sendSlashCommand("/submit") }
            } label: {
                Text("제출")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(appState.isStreaming)
            .help("/submit 명령 실행")

            Button {
                appState.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("새 대화")
            .disabled(appState.isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .sheet(isPresented: $showStartInput) {
            startInputSheet
        }
    }

    // MARK: - Start Input Sheet

    private var startInputSheet: some View {
        VStack(spacing: 16) {
            Text("작업 설명 입력")
                .font(.headline)

            TextField("설명을 입력하세요...", text: $startDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .frame(minWidth: 300)

            HStack {
                Button("취소") {
                    showStartInput = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("시작") {
                    let description = startDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    showStartInput = false
                    if !description.isEmpty {
                        appState.isStartMode = true
                        showStartResponse = true
                        Task { await appState.sendSlashCommand("/start \(description)") }
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(startDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }

    // MARK: - Start Response Overlay

    private var startResponseOverlay: some View {
        ZStack {
            // 배경 딤
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // 팝업
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Label("/start 응답", systemImage: "play.circle.fill")
                        .font(.headline)

                    Spacer()

                    if appState.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // 응답 내용
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if let lastAssistant = appState.messages.last(where: { $0.role == .assistant }) {
                                Text(lastAssistant.content)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("start-response-text")
                            } else if appState.isStreaming {
                                Text(appState.isThinking ? "생각하는 중..." : "응답 대기 중...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .id("start-response-text")
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: appState.messages.last(where: { $0.role == .assistant })?.content) { _, _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("start-response-text", anchor: .bottom)
                        }
                    }
                }

                Divider()

                // 하단 상태
                HStack {
                    if appState.isStreaming {
                        Text("응답 완료 시 자동으로 닫힙니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("닫기") {
                        showStartResponse = false
                        appState.isStartMode = false
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(minWidth: 500, maxWidth: 500, minHeight: 200, maxHeight: 400)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
        }
    }

    // MARK: - Start Completion Handler

    private func handleStartCompletion() {
        // 마지막 assistant 응답에서 마지막 문장 추출
        guard let lastAssistant = appState.messages.last(where: { $0.role == .assistant }) else {
            showStartResponse = false
            appState.isStartMode = false
            return
        }

        let lastSentence = extractLastSentence(from: lastAssistant.content)

        showStartResponse = false
        appState.isStartMode = false

        // 새 세션 시작 + 마지막 문장으로 메시지 전송
        appState.startNewChat()
        if !lastSentence.isEmpty {
            appState.inputText = lastSentence
            Task { await appState.send() }
        }
    }

    /// 텍스트에서 마지막 의미 있는 문장을 추출
    private func extractLastSentence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 줄 단위로 분리 후 마지막 비어있지 않은 줄 반환
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.last ?? trimmed
    }

    // MARK: - Messages

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if appState.isStreaming && !appState.isStartMode {
                        streamingIndicator
                            .id("streaming-indicator")
                    }

                    // 작업 요약 + 웹 미리보기 (스트리밍 완료 후 표시)
                    if !appState.isStreaming && !messages.isEmpty {
                        ActivitySummaryView(messages: messages)
                            .id("activity-summary")

                        WebPreviewButton(messages: messages)
                            .id("web-preview")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.isStreaming) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)

            Text(appState.isThinking ? "생각하는 중..." : "응답 생성 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            CopyConversationButton(messages: messages)

            TextField("메시지를 입력하세요...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onKeyPress(.return, phases: .down) { keyPress in
                    if keyPress.modifiers.contains(.shift) {
                        return .ignored
                    }
                    sendMessage()
                    return .handled
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var messages: [ChatMessage] {
        appState.messages
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.inputText = text
        inputText = ""
        Task { await appState.send() }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if appState.isStreaming {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("streaming-indicator", anchor: .bottom)
            }
        } else if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
