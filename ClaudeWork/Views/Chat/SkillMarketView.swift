import SwiftUI

/// 스킬 마켓플레이스 패널 — 오버레이로 표시.
struct SkillMarketView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedFilter = "전체"
    @State private var selectedPlugin: MarketplacePlugin?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ClaudeThemeDivider()
            searchAndFilterBar
            ClaudeThemeDivider()
            pluginGrid
        }
        .frame(width: 860, height: 720)
        .background(ClaudeTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(ClaudeTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 24, y: 8)
        .task {
            if appState.marketplaceCatalog.isEmpty {
                await appState.loadMarketplace()
            }
        }
        .sheet(item: $selectedPlugin) { plugin in
            PluginDetailView(
                plugin: plugin,
                isInstalled: appState.marketplaceInstalledNames.contains(plugin.name),
                installStatus: appState.marketplacePluginStates[plugin.id] ?? .notInstalled,
                onInstall: {
                    Task { await appState.installMarketplacePlugin(plugin) }
                },
                onUninstall: {
                    Task { await appState.uninstallMarketplacePlugin(plugin) }
                }
            )
        }
    }

    // MARK: - 헤더

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundStyle(ClaudeTheme.accent)

            Text("스킬 마켓플레이스")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ClaudeTheme.textPrimary)

            Spacer()

            Button {
                Task { await appState.loadMarketplace(forceRefresh: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .disabled(appState.marketplaceLoading)
            .help("새로고침")

            Button {
                appState.showMarketplace = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("닫기")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 검색 & 필터

    private var searchAndFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textTertiary)

                TextField("스킬 검색...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(ClaudeTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ClaudeTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall)
                    .strokeBorder(ClaudeTheme.borderSubtle, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip("전체")
                    filterChip("설치됨")

                    ForEach(availableCategories, id: \.self) { cat in
                        filterChip(cat)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func filterChip(_ label: String) -> some View {
        Button {
            selectedFilter = label
        } label: {
            Text(label)
                .font(.system(size: 11, weight: selectedFilter == label ? .semibold : .regular))
                .foregroundStyle(selectedFilter == label ? ClaudeTheme.textOnAccent : ClaudeTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selectedFilter == label ? ClaudeTheme.accent : ClaudeTheme.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 플러그인 그리드

    private var pluginGrid: some View {
        Group {
            if appState.marketplaceLoading && appState.marketplaceCatalog.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("카탈로그를 불러오는 중...")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPlugins.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Text("검색 결과가 없습니다")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(filteredPlugins) { plugin in
                            PluginCard(
                                plugin: plugin,
                                isInstalled: appState.marketplaceInstalledNames.contains(plugin.name),
                                installStatus: appState.marketplacePluginStates[plugin.id] ?? .notInstalled
                            )
                            .onTapGesture {
                                selectedPlugin = plugin
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - 계산 프로퍼티

    private var filteredPlugins: [MarketplacePlugin] {
        var plugins = appState.marketplaceCatalog

        if selectedFilter == "설치됨" {
            plugins = plugins.filter { appState.marketplaceInstalledNames.contains($0.name) }
        } else if selectedFilter != "전체" {
            plugins = plugins.filter { $0.categoryLabel == selectedFilter || $0.marketplace == selectedFilter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            plugins = plugins.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.author.lowercased().contains(query) ||
                $0.category.lowercased().contains(query)
            }
        }

        return plugins
    }

    private var availableCategories: [String] {
        var categoryCounts: [String: Int] = [:]
        for plugin in appState.marketplaceCatalog {
            categoryCounts[plugin.categoryLabel, default: 0] += 1
        }
        return Array(categoryCounts.sorted { $0.value > $1.value }.prefix(8).map(\.key))
    }
}

// MARK: - 플러그인 카드 (그리드용)

struct PluginCard: View {
    let plugin: MarketplacePlugin
    let isInstalled: Bool
    let installStatus: PluginInstallStatus

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 태그
            HStack(spacing: 4) {
                Text(plugin.categoryLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ClaudeTheme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ClaudeTheme.accentSubtle)
                    .clipShape(Capsule())

                Text(plugin.marketplace)
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ClaudeTheme.surfaceTertiary)
                    .clipShape(Capsule())

                Spacer()
            }

            // 이름
            Text(plugin.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ClaudeTheme.textPrimary)

            // 설명
            Text(plugin.description)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textSecondary)
                .lineLimit(3)

            // 하단 정보
            HStack(spacing: 6) {
                Image(systemName: "person")
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                Text(plugin.author)
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)

                Spacer()

                installBadge
            }
        }
        .padding(14)
        .background(isHovering ? ClaudeTheme.surfacePrimary : ClaudeTheme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                .strokeBorder(ClaudeTheme.borderSubtle, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var installBadge: some View {
        switch installStatus {
        case .notInstalled:
            if isInstalled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ClaudeTheme.statusSuccess)
                        .frame(width: 6, height: 6)
                    Text("설치됨")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ClaudeTheme.statusSuccess)
                }
            }
        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("설치 중...")
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.textTertiary)
            }
        case .installed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.statusSuccess)
                Text("설치됨")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ClaudeTheme.statusSuccess)
            }
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ClaudeTheme.statusError)
                Text("실패")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ClaudeTheme.statusError)
            }
            .help(message)
        }
    }
}

// MARK: - 플러그인 상세 페이지

struct PluginDetailView: View {
    let plugin: MarketplacePlugin
    let isInstalled: Bool
    let installStatus: PluginInstallStatus
    let onInstall: () -> Void
    let onUninstall: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("뒤로")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(ClaudeTheme.textSecondary)
                }
                .buttonStyle(.borderless)

                Spacer()

                actionButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ClaudeThemeDivider()

            // 내용
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 카테고리
                    HStack(spacing: 6) {
                        Text(plugin.categoryLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ClaudeTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ClaudeTheme.accentSubtle)
                            .clipShape(Capsule())

                        Text(plugin.sourceType.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ClaudeTheme.surfaceSecondary)
                            .clipShape(Capsule())
                    }

                    // 이름
                    Text(plugin.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ClaudeTheme.textPrimary)

                    // 설명
                    Text(plugin.description)
                        .font(.system(size: 14))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ClaudeThemeDivider()

                    // 정보 그리드
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                        infoRow(label: "작성자", value: plugin.author)
                        infoRow(label: "마켓", value: plugin.marketplace)
                        infoRow(label: "카테고리", value: plugin.categoryLabel)
                        if !plugin.homepage.isEmpty {
                            infoRow(label: "홈페이지", value: plugin.homepage)
                        }
                    }

                    ClaudeThemeDivider()

                    // 설치 명령어 안내
                    VStack(alignment: .leading, spacing: 6) {
                        Text("설치 명령어")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ClaudeTheme.textPrimary)

                        Text(plugin.installCommand)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ClaudeTheme.textTertiary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ClaudeTheme.codeBackground)
                            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 620, height: 500)
        .background(ClaudeTheme.surfaceElevated)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ClaudeTheme.textPrimary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch installStatus {
        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("설치 중...")
                    .font(.system(size: 13))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
        case .installed, .notInstalled where isInstalled:
            Button("삭제", action: onUninstall)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ClaudeTheme.statusError)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(ClaudeTheme.statusError.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
        case .failed:
            Button("재시도", action: onInstall)
                .buttonStyle(ClaudeAccentButtonStyle())
        default:
            Button("설치", action: onInstall)
                .buttonStyle(ClaudeAccentButtonStyle())
        }
    }
}

// MARK: - Identifiable for sheet

extension MarketplacePlugin: Hashable {
    static func == (lhs: MarketplacePlugin, rhs: MarketplacePlugin) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    SkillMarketView()
        .environment(AppState())
        .frame(width: 860, height: 720)
}
