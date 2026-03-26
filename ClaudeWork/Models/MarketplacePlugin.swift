import Foundation

/// 마켓플레이스 카탈로그의 플러그인/스킬 항목.
struct MarketplacePlugin: Identifiable, Codable, Sendable {
    var id: String { "\(repo)/\(sourcePath)" }
    let name: String
    let description: String
    let version: String
    let author: String
    let repo: String
    let sourcePath: String
    let installName: String
    let category: String
    let tags: [String]
    let isSkillMd: Bool

    /// 카테고리 한글 라벨.
    var categoryLabel: String {
        switch category {
        case "agent-skills": return "에이전트 스킬"
        case "knowledge-work": return "지식 작업"
        case "financial-services": return "금융 서비스"
        default: return category.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

/// 플러그인 설치 상태.
enum PluginInstallStatus: Sendable {
    case notInstalled
    case installing
    case installed
    case failed(String)
}
