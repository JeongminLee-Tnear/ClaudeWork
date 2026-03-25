import Foundation

// MARK: - GitHub User

struct GitHubUser: Codable, Sendable {
    let login: String
    let name: String?
    let avatarUrl: String

    private enum CodingKeys: String, CodingKey {
        case login
        case name
        case avatarUrl = "avatar_url"
    }
}

// MARK: - GitHub Repo

struct GitHubRepo: Identifiable, Codable, Sendable {
    let id: Int
    let fullName: String
    let name: String
    let owner: Owner
    let isPrivate: Bool
    let htmlUrl: String

    struct Owner: Codable, Sendable {
        let login: String
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case name
        case owner
        case isPrivate = "private"
        case htmlUrl = "html_url"
    }
}

// MARK: - Device Flow: Device Code Response

struct DeviceCodeResponse: Codable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    private enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

// MARK: - Device Flow: Access Token Response

struct AccessTokenResponse: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}
