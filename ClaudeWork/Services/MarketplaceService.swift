import Foundation
import os

/// Fetches the marketplace catalog from Anthropic's GitHub repositories
/// and handles skill installation/uninstallation.
actor MarketplaceService {

    private let logger = Logger(subsystem: "com.claudework", category: "MarketplaceService")

    /// Cached catalog with TTL.
    private var cachedCatalog: [MarketplacePlugin] = []
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 300 // 5 minutes

    /// Source repositories to scan for plugins.
    private static let sourceRepos: [(owner: String, repo: String, category: String)] = [
        ("anthropics", "skills", "agent-skills"),
        ("anthropics", "knowledge-work-plugins", "knowledge-work"),
        ("anthropics", "financial-services-plugins", "financial-services"),
    ]

    // MARK: - Fetch Catalog

    /// Fetch the full marketplace catalog, using cache when available.
    func fetchCatalog(forceRefresh: Bool = false) async -> [MarketplacePlugin] {
        if !forceRefresh,
           let cacheDate,
           Date().timeIntervalSince(cacheDate) < cacheTTL,
           !cachedCatalog.isEmpty {
            return cachedCatalog
        }

        var allPlugins: [MarketplacePlugin] = []

        await withTaskGroup(of: [MarketplacePlugin].self) { group in
            for source in Self.sourceRepos {
                group.addTask {
                    await self.fetchRepoPlugins(
                        owner: source.owner,
                        repo: source.repo,
                        category: source.category
                    )
                }
            }
            for await plugins in group {
                allPlugins.append(contentsOf: plugins)
            }
        }

        allPlugins.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        cachedCatalog = allPlugins
        cacheDate = Date()

        logger.info("Fetched \(allPlugins.count) plugins from marketplace")
        return allPlugins
    }

    /// Fetch plugins from a single repository.
    private func fetchRepoPlugins(owner: String, repo: String, category: String) async -> [MarketplacePlugin] {
        // Try to fetch the marketplace.json catalog first
        let catalogURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/main/.claude-plugin/marketplace.json"

        guard let url = URL(string: catalogURL) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // Fallback: scan the repo tree for SKILL.md files
                return await scanRepoTree(owner: owner, repo: repo, category: category)
            }

            return parseMarketplaceCatalog(data: data, owner: owner, repo: repo, category: category)
        } catch {
            logger.warning("Failed to fetch catalog from \(owner)/\(repo): \(error.localizedDescription)")
            return await scanRepoTree(owner: owner, repo: repo, category: category)
        }
    }

    /// Parse a marketplace.json catalog file.
    private func parseMarketplaceCatalog(data: Data, owner: String, repo: String, category: String) -> [MarketplacePlugin] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [[String: Any]] else {
            return []
        }

        return plugins.compactMap { entry -> MarketplacePlugin? in
            guard let name = entry["name"] as? String else { return nil }
            let description = entry["description"] as? String ?? ""
            let version = entry["version"] as? String ?? "1.0.0"
            let author = entry["author"] as? String ?? owner
            let sourcePath = entry["path"] as? String ?? name
            let installName = entry["installName"] as? String ?? name
            let tags = entry["tags"] as? [String] ?? []
            let isSkillMd = entry["isSkillMd"] as? Bool ?? true

            return MarketplacePlugin(
                name: name,
                description: description,
                version: version,
                author: author,
                repo: "\(owner)/\(repo)",
                sourcePath: sourcePath,
                installName: installName,
                category: category,
                tags: tags,
                isSkillMd: isSkillMd
            )
        }
    }

    /// Fallback: scan the repo tree via GitHub API for SKILL.md files.
    private func scanRepoTree(owner: String, repo: String, category: String) async -> [MarketplacePlugin] {
        let treeURL = "https://api.github.com/repos/\(owner)/\(repo)/git/trees/main?recursive=1"
        guard let url = URL(string: treeURL) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tree = json["tree"] as? [[String: Any]] else { return [] }

            // Find SKILL.md files
            let skillPaths = tree.compactMap { item -> String? in
                guard let path = item["path"] as? String,
                      path.hasSuffix("/SKILL.md") || path == "SKILL.md" else { return nil }
                return path
            }

            var plugins: [MarketplacePlugin] = []
            for path in skillPaths {
                if let plugin = await fetchSkillMd(
                    owner: owner,
                    repo: repo,
                    path: path,
                    category: category
                ) {
                    plugins.append(plugin)
                }
            }
            return plugins
        } catch {
            logger.warning("Failed to scan tree for \(owner)/\(repo): \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch and parse a single SKILL.md file from GitHub.
    private func fetchSkillMd(owner: String, repo: String, path: String, category: String) async -> MarketplacePlugin? {
        let rawURL = "https://raw.githubusercontent.com/\(owner)/\(repo)/main/\(path)"
        guard let url = URL(string: rawURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let content = String(data: data, encoding: .utf8) else { return nil }

            let dirName: String
            if path.contains("/") {
                dirName = String(path.split(separator: "/").dropLast().last ?? "")
            } else {
                dirName = repo
            }

            return parseSkillMdContent(content, dirName: dirName, owner: owner, repo: repo, path: path, category: category)
        } catch {
            return nil
        }
    }

    /// Parse SKILL.md frontmatter into a MarketplacePlugin.
    private func parseSkillMdContent(_ content: String, dirName: String, owner: String, repo: String, path: String, category: String) -> MarketplacePlugin? {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var name = dirName
        var description = ""
        var tags: [String] = []

        for i in 1..<lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }

            if line.hasPrefix("name:") {
                let val = line.dropFirst(5).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                if !val.isEmpty { name = val }
            } else if line.hasPrefix("description:") {
                let val = line.dropFirst(12).trimmingCharacters(in: .whitespaces)
                description = val.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            } else if line.hasPrefix("tags:") {
                let val = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if val.hasPrefix("[") {
                    // Inline array: [tag1, tag2]
                    let inner = val.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    tags = inner.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    }
                }
            }
        }

        // Clean description
        if description.count > 120 {
            description = String(description.prefix(117)) + "..."
        }

        return MarketplacePlugin(
            name: name,
            description: description,
            version: "1.0.0",
            author: owner,
            repo: "\(owner)/\(repo)",
            sourcePath: path,
            installName: dirName,
            category: category,
            tags: tags,
            isSkillMd: true
        )
    }

    // MARK: - Installation

    /// Get names of currently installed skills.
    func installedSkillNames() -> Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let skillsDir = "\(home)/.claude/skills"
        let fm = FileManager.default

        guard fm.fileExists(atPath: skillsDir) else { return [] }

        do {
            let entries = try fm.contentsOfDirectory(atPath: skillsDir)
            return Set(entries.map { entry in
                if entry.hasSuffix(".md") {
                    return String(entry.dropLast(3))
                }
                return entry
            })
        } catch {
            return []
        }
    }

    /// Install a skill from the marketplace.
    func installPlugin(_ plugin: MarketplacePlugin) async throws {
        guard plugin.isSkillMd else {
            throw MarketplaceError.unsupportedPluginType
        }

        // Fetch the SKILL.md content
        let rawURL = "https://raw.githubusercontent.com/\(plugin.repo)/main/\(plugin.sourcePath)"
        guard let url = URL(string: rawURL) else {
            throw MarketplaceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketplaceError.fetchFailed
        }

        // Write to ~/.claude/skills/<name>/SKILL.md
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let skillDir = "\(home)/.claude/skills/\(plugin.installName)"
        let fm = FileManager.default

        try fm.createDirectory(atPath: skillDir, withIntermediateDirectories: true)

        let destPath = "\(skillDir)/SKILL.md"
        try data.write(to: URL(fileURLWithPath: destPath))

        logger.info("Installed skill: \(plugin.name) to \(destPath, privacy: .public)")
    }

    /// Uninstall a skill by removing its directory.
    func uninstallPlugin(_ plugin: MarketplacePlugin) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let skillDir = "\(home)/.claude/skills/\(plugin.installName)"
        let fm = FileManager.default

        guard fm.fileExists(atPath: skillDir) else {
            throw MarketplaceError.notInstalled
        }

        try fm.removeItem(atPath: skillDir)
        logger.info("Uninstalled skill: \(plugin.name)")
    }

    // MARK: - Errors

    enum MarketplaceError: LocalizedError {
        case unsupportedPluginType
        case invalidURL
        case fetchFailed
        case notInstalled

        var errorDescription: String? {
            switch self {
            case .unsupportedPluginType: return "이 플러그인 유형은 직접 설치를 지원하지 않습니다."
            case .invalidURL: return "잘못된 플러그인 URL입니다."
            case .fetchFailed: return "플러그인 콘텐츠를 가져오지 못했습니다."
            case .notInstalled: return "플러그인이 설치되어 있지 않습니다."
            }
        }
    }
}
