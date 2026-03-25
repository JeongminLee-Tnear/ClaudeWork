import Foundation

struct Project: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var gitHubRepo: String?
    var lastSessionId: String?

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        gitHubRepo: String? = nil,
        lastSessionId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.gitHubRepo = gitHubRepo
        self.lastSessionId = lastSessionId
    }
}
