import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var isInputFocused: Bool
    @State private var showStartResponse = false
    @State private var showFilePicker = false
    @State private var showSlashPopup = false
    @State private var slashSelectedIndex = 0
    @State private var slashDetailCommand: SlashCommand?
    @State private var textPreviewAttachment: Attachment?
    @State private var isDragOver = false
    @State private var lastPasteChangeCount = 0
    @State private var showAtFilePopup = false
    @State private var atFileSelectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            toolbarArea

            ClaudeThemeDivider()

            messageScrollView

            inputBar
        }
        .background(ClaudeTheme.background)
        .overlay {
            // /start 응답 팝업
            if showStartResponse {
                startResponseOverlay
            }
        }
        .overlay {
            // Skill Marketplace 패널
            if appState.showMarketplace {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                appState.showMarketplace = false
                            }
                        }

                    SkillMarketView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .onChange(of: appState.isStreaming) { old, new in
            // Start 모드에서 스트리밍 완료 시 → 마지막 문장 복사 후 새 세션
            if old && !new && appState.isStartMode {
                handleStartCompletion()
            }
        }
        .onChange(of: appState.requestInputFocus) { _, newValue in
            if newValue {
                isInputFocused = true
                appState.requestInputFocus = false
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarArea: some View {
        HStack(spacing: 12) {
            if let project = appState.selectedProject {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.accent)
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ClaudeTheme.textPrimary)

                    if let role = appState.setup.getProjectRole(at: project.path) {
                        Text(role.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(roleColor(role))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor(role).opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer()

            Picker("", selection: Bindable(appState).selectedModel) {
                ForEach(AppState.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ClaudeTheme.surfaceElevated)
    }

    // MARK: - Start Response Overlay

    private var startResponseOverlay: some View {
        ZStack {
            // 배경 딤
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // 팝업
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(ClaudeTheme.accent)
                        Text("/start 응답")
                            .font(.headline)
                            .foregroundStyle(ClaudeTheme.textPrimary)
                    }

                    Spacer()

                    if appState.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                ClaudeThemeDivider()

                // 응답 내용
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if let lastAssistant = appState.messages.last(where: { $0.role == .assistant }) {
                                Text(lastAssistant.content)
                                    .font(.body)
                                    .foregroundStyle(ClaudeTheme.textPrimary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("start-response-text")
                            } else if appState.isStreaming {
                                Text(appState.isThinking ? "생각하는 중..." : "응답 대기 중...")
                                    .font(.subheadline)
                                    .foregroundStyle(ClaudeTheme.textSecondary)
                                    .id("start-response-text")
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: appState.messages.last(where: { $0.role == .assistant })?.content) { _, _ in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("start-response-text", anchor: .bottom)
                        }
                    }
                }

                ClaudeThemeDivider()

                // 하단 상태
                HStack {
                    if appState.isStreaming {
                        Text("응답 완료 시 자동으로 닫힙니다")
                            .font(.caption)
                            .foregroundStyle(ClaudeTheme.textTertiary)
                    }

                    Spacer()

                    Button("닫기") {
                        showStartResponse = false
                        appState.isStartMode = false
                    }
                    .buttonStyle(ClaudeSecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(minWidth: 500, maxWidth: 500, minHeight: 200, maxHeight: 400)
            .background(ClaudeTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusLarge))
            .shadow(color: ClaudeTheme.shadowColor, radius: 20)
        }
    }

    // MARK: - Start Completion Handler

    private func handleStartCompletion() {
        guard let lastAssistant = appState.messages.last(where: { $0.role == .assistant }) else {
            showStartResponse = false
            appState.isStartMode = false
            return
        }

        let lastSentence = extractLastSentence(from: lastAssistant.content)

        showStartResponse = false
        appState.isStartMode = false

        appState.startNewChat()
        if !lastSentence.isEmpty {
            appState.inputText = lastSentence
            Task { await appState.send() }
        }
    }

    private func extractLastSentence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.last ?? trimmed
    }

    // MARK: - Messages

    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appState.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if appState.isStreaming && !appState.isStartMode {
                        streamingIndicator
                            .id("streaming-indicator")
                    }

                    // 작업 요약 + 웹 미리보기 (스트리밍 완료 후 표시)
                    if !appState.isStreaming && !appState.messages.isEmpty {
                        ActivitySummaryView(messages: appState.messages)
                            .id("activity-summary")

                        WebPreviewButton(messages: appState.messages)
                            .id("web-preview")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: appState.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.isStreaming) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            isInputFocused = true
        })
    }

    private var streamingIndicator: some View {
        HStack(spacing: 8) {
            PulseRingView()

            Text(appState.isThinking ? "생각하는 중..." : "응답 생성 중...")
                .font(.system(size: 13))
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ClaudeTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
    }

    // MARK: - Input Bar

    private var slashQuery: String {
        let trimmed = appState.inputText.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/") else { return "" }
        if !trimmed.contains(" ") {
            return trimmed
        }
        return ""
    }

    private var slashFilteredCommands: [SlashCommand] {
        SlashCommandRegistry.filtered(by: slashQuery)
    }

    /// 마지막 `@` 이후 텍스트를 쿼리로 추출. @ 뒤에 공백 없이 타이핑 중일 때만 반환.
    private var atFileQuery: String {
        let text = appState.inputText
        guard let atRange = text.range(of: "@", options: .backwards) else { return "" }
        let afterAt = String(text[atRange.upperBound...])
        // 공백이 있으면 이미 선택 완료된 것
        if afterAt.contains(" ") { return "" }
        return afterAt
    }

    private var atFileFilteredEntries: [AtFileEntry] {
        guard let project = appState.selectedProject else { return [] }
        return AtFileSearch.search(query: atFileQuery, projectPath: project.path)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            // 첨부파일 미리보기
            if !appState.attachments.isEmpty {
                attachmentPreviews
            }

            // 슬래시 명령어 팝업
            if showSlashPopup && !slashFilteredCommands.isEmpty {
                SlashCommandPopup(
                    query: slashQuery,
                    onSelect: { cmd in
                        selectSlashCommand(cmd)
                    },
                    selectedIndex: $slashSelectedIndex
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // @ 파일 검색 팝업
            if showAtFilePopup && !atFileFilteredEntries.isEmpty {
                AtFilePopup(
                    entries: atFileFilteredEntries,
                    onSelect: { relativePath in
                        selectAtFile(relativePath)
                    },
                    selectedIndex: $atFileSelectedIndex
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                // 파일 첨부 버튼
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("파일 첨부")
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImport(result)
                }

                TextField("메시지를 입력하세요...", text: Bindable(appState).inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(ClaudeTheme.textPrimary)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onChange(of: appState.inputText) { oldValue, newValue in
                        // 붙여넣기 감지: delta > 1 && 페이스트보드 changeCount가 변했을 때만
                        let pbCount = NSPasteboard.general.changeCount
                        let delta = newValue.count - oldValue.count
                        if delta > 1 && pbCount != lastPasteChangeCount {
                            lastPasteChangeCount = pbCount
                            if let attachment = detectPasteAttachment() {
                                appState.addAttachment(attachment)
                                appState.inputText = oldValue
                                return
                            }
                        }

                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        let shouldShowSlash = trimmed.hasPrefix("/") && !trimmed.contains(" ")
                        withAnimation(.easeOut(duration: 0.15)) {
                            showSlashPopup = shouldShowSlash
                        }
                        if shouldShowSlash {
                            slashSelectedIndex = 0
                        }

                        // @ 파일 검색 감지
                        let shouldShowAt = !shouldShowSlash && hasActiveAtQuery(in: newValue)
                        withAnimation(.easeOut(duration: 0.15)) {
                            showAtFilePopup = shouldShowAt
                        }
                        if shouldShowAt {
                            atFileSelectedIndex = 0
                        }
                    }
                    .onKeyPress(.return, phases: .down) { keyPress in
                        if keyPress.modifiers.contains(.shift) {
                            return .ignored
                        }
                        if showSlashPopup && !slashFilteredCommands.isEmpty {
                            let commands = slashFilteredCommands
                            if slashSelectedIndex < commands.count {
                                if keyPress.modifiers.contains(.command) {
                                    let cmd = commands[slashSelectedIndex]
                                    if cmd.detailDescription != nil {
                                        slashDetailCommand = cmd
                                    }
                                } else {
                                    selectSlashCommand(commands[slashSelectedIndex])
                                }
                            }
                            return .handled
                        }
                        // @ 파일 팝업에서 Enter → 경로 삽입
                        if showAtFilePopup && !atFileFilteredEntries.isEmpty {
                            let entries = atFileFilteredEntries
                            if atFileSelectedIndex < entries.count {
                                selectAtFile(entries[atFileSelectedIndex].relativePath)
                            }
                            return .handled
                        }
                        sendMessage()
                        return .handled
                    }
                    .onKeyPress(.upArrow, phases: .down) { _ in
                        if showAtFilePopup && !atFileFilteredEntries.isEmpty {
                            let count = atFileFilteredEntries.count
                            atFileSelectedIndex = (atFileSelectedIndex - 1 + count) % count
                            return .handled
                        }
                        guard showSlashPopup && !slashFilteredCommands.isEmpty else { return .ignored }
                        let count = slashFilteredCommands.count
                        slashSelectedIndex = (slashSelectedIndex - 1 + count) % count
                        return .handled
                    }
                    .onKeyPress(.downArrow, phases: .down) { _ in
                        if showAtFilePopup && !atFileFilteredEntries.isEmpty {
                            let count = atFileFilteredEntries.count
                            atFileSelectedIndex = (atFileSelectedIndex + 1) % count
                            return .handled
                        }
                        guard showSlashPopup && !slashFilteredCommands.isEmpty else { return .ignored }
                        let count = slashFilteredCommands.count
                        slashSelectedIndex = (slashSelectedIndex + 1) % count
                        return .handled
                    }
                    .onKeyPress(.tab, phases: .down) { _ in
                        if showAtFilePopup && !atFileFilteredEntries.isEmpty {
                            let entries = atFileFilteredEntries
                            if atFileSelectedIndex < entries.count {
                                selectAtFile(entries[atFileSelectedIndex].relativePath)
                            }
                            return .handled
                        }
                        guard showSlashPopup && !slashFilteredCommands.isEmpty else { return .ignored }
                        let commands = slashFilteredCommands
                        if slashSelectedIndex < commands.count {
                            selectSlashCommand(commands[slashSelectedIndex])
                        }
                        return .handled
                    }
                    .onKeyPress(.escape, phases: .down) { _ in
                        if showAtFilePopup {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showAtFilePopup = false
                            }
                            return .handled
                        }
                        guard showSlashPopup else { return .ignored }
                        withAnimation(.easeOut(duration: 0.15)) {
                            showSlashPopup = false
                        }
                        return .handled
                    }

                if !showSlashPopup {
                    ClaudeSendButton(
                        isEnabled: !appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !appState.attachments.isEmpty,
                        action: sendMessage
                    )
                    .disabled(appState.isStreaming)
                    .keyboardShortcut(.return, modifiers: .command)
                } else {
                    ClaudeSendButton(
                        isEnabled: false,
                        action: {}
                    )
                    .disabled(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ClaudeTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill)
                    .strokeBorder(ClaudeTheme.inputBorder, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .sheet(item: $slashDetailCommand) { cmd in
                CommandDetailSheet(command: cmd)
            }
            .sheet(item: $textPreviewAttachment) { attachment in
                TextPreviewSheet(attachment: attachment)
            }
            .onDrop(of: [.fileURL, .image], isTargeted: $isDragOver) { providers in
                processItemProviders(providers)
                return true
            }
            .overlay {
                if isDragOver {
                    RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill)
                        .strokeBorder(ClaudeTheme.accent.opacity(0.6), lineWidth: 2, antialiased: true)
                        .background(ClaudeTheme.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill))
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func selectSlashCommand(_ cmd: SlashCommand) {
        withAnimation(.easeOut(duration: 0.15)) {
            showSlashPopup = false
        }
        if cmd.acceptsInput {
            // 입력 가능 명령어 → 인풋에 "/명령어 " 삽입하고 대기
            appState.inputText = cmd.command + " "
        } else {
            appState.inputText = ""
            Task { await appState.sendSlashCommand(cmd.command) }
        }
    }

    // MARK: - @ File Selection

    private func selectAtFile(_ relativePath: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            showAtFilePopup = false
        }
        // 마지막 @ 이후 텍스트를 경로로 교체
        var text = appState.inputText
        if let atRange = text.range(of: "@", options: .backwards) {
            text.replaceSubrange(atRange.lowerBound..., with: "@\(relativePath) ")
        }
        appState.inputText = text
    }

    private func hasActiveAtQuery(in text: String) -> Bool {
        guard let atRange = text.range(of: "@", options: .backwards) else { return false }
        let afterAt = String(text[atRange.upperBound...])
        // 공백이 있으면 이미 선택 완료
        return !afterAt.contains(" ")
    }

    // MARK: - Attachment Previews

    private var attachmentPreviews: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.attachments) { attachment in
                    AttachmentPreviewItem(attachment: attachment) {
                        appState.removeAttachment(attachment.id)
                    } onTap: {
                        if attachment.type == .text {
                            textPreviewAttachment = attachment
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Helpers

    private func sendMessage() {
        guard !appState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !appState.attachments.isEmpty else { return }
        Task { await appState.send() }
    }

    // MARK: - Paste & File Import

    private func processItemProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasRepresentationConforming(toTypeIdentifier: UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    if let attachment = AttachmentFactory.fromFileURL(url) {
                        DispatchQueue.main.async {
                            appState.addAttachment(attachment)
                        }
                    }
                }
            } else if provider.hasRepresentationConforming(toTypeIdentifier: UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { return }
                    let name = "drop-\(UUID().uuidString.prefix(8)).png"
                    let attachment = Attachment(type: .image, name: name, imageData: data)
                    DispatchQueue.main.async {
                        appState.addAttachment(attachment)
                    }
                }
            }
        }
    }


    /// 페이스트보드에서 이미지/파일/긴텍스트를 감지해서 Attachment 반환
    private func detectPasteAttachment() -> Attachment? {
        let pb = NSPasteboard.general

        // 파일 URL 우선 — Finder 복사 시 TIFF는 파일 아이콘이므로 파일에서 직접 읽어야 함
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first(where: \.isFileURL) {
            return AttachmentFactory.fromFileURL(url)
        }

        // 순수 이미지 데이터 (스크린샷, 웹에서 이미지 복사 등)
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pb.data(forType: type) {
                return Attachment(type: .image, name: "clipboard-\(UUID().uuidString.prefix(8)).png", imageData: data)
            }
        }

        // 긴 텍스트
        if let text = pb.string(forType: .string),
           text.count >= AttachmentFactory.longTextThreshold {
            return AttachmentFactory.fromLongText(text)
        }

        return nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            if let attachment = AttachmentFactory.fromFileURL(url) {
                appState.addAttachment(attachment)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if appState.isStreaming {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("streaming-indicator", anchor: .bottom)
            }
        } else if let lastMessage = appState.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func roleColor(_ role: ProjectRole) -> Color {
        switch role {
        case .dev: .blue
        case .po: .orange
        case .design: .purple
        }
    }
}

#Preview {
    ChatView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
