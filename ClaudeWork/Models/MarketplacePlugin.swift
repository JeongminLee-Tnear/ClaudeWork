import Foundation

/// 마켓플레이스 카탈로그의 플러그인/스킬 항목.
struct MarketplacePlugin: Identifiable, Codable, Sendable {
    var id: String { "\(marketplace)/\(name)" }
    let name: String
    let description: String
    let author: String
    let category: String
    let homepage: String
    /// 플러그인이 속한 마켓플레이스 이름 (e.g. "claude-plugins-official")
    let marketplace: String
    /// source 유형: "local", "url", "git-subdir", "skills-bundle"
    let sourceType: SourceType
    /// 하위 스킬 경로 목록 (skills 저장소의 번들 플러그인용)
    let skillPaths: [String]

    enum SourceType: String, Codable, Sendable {
        /// 같은 저장소 내 로컬 경로 (e.g. "./plugins/name")
        case local
        /// 외부 git URL (e.g. "https://github.com/org/repo.git")
        case url
        /// 외부 git 저장소의 하위 디렉토리
        case gitSubdir = "git-subdir"
        /// 하위 스킬들의 번들 (skills 저장소 형식)
        case skillsBundle = "skills-bundle"
    }

    /// 카테고리 한글 라벨.
    var categoryLabel: String {
        switch category {
        case "official": return "공식 플러그인"
        case "development": return "개발 도구"
        case "productivity": return "생산성"
        case "location": return "위치 서비스"
        case "agent-skills": return "에이전트 스킬"
        case "knowledge-work": return "지식 작업"
        case "financial-services": return "금융 서비스"
        default: return category.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    /// 마켓플레이스(출처) 한글 라벨.
    var marketplaceLabel: String {
        switch marketplace {
        case "claude-plugins-official": return "공식 플러그인"
        case "anthropic-agent-skills": return "에이전트 스킬"
        case "knowledge-work-plugins": return "지식 작업"
        case "financial-services-plugins": return "금융 서비스"
        default: return marketplace
        }
    }

    /// 설치 명령어 텍스트 (UI 표시용)
    var installCommand: String {
        "/plugin install \(name)@\(marketplace)"
    }
}

/// 플러그인 설치 상태.
enum PluginInstallStatus: Sendable {
    case notInstalled
    case installing
    case installed
    case failed(String)
}
