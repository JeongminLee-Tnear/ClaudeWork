import Foundation
import os
import Security

actor GitHubService {

    static let oauthClientId = "Ov23liaj3hlJoMGsNZTW"
    private let clientId = oauthClientId
    private let logger = Logger(subsystem: "com.claudework", category: "GitHubService")
    private let sshKeyManager = SSHKeyManager()

    private(set) var accessToken: String?
    private(set) var currentUser: GitHubUser?

    // MARK: - Errors

    enum GitHubError: LocalizedError {
        case noAccessToken
        case deviceCodeExpired
        case accessDenied
        case networkError(String)
        case apiError(Int, String)
        case decodingError(String)
        case cloneFailed(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .noAccessToken:
                return "Not authenticated. Please sign in with GitHub."
            case .deviceCodeExpired:
                return "The device code has expired. Please restart the login process."
            case .accessDenied:
                return "Access was denied. Please try again and authorize the app."
            case .networkError(let detail):
                return "Network error: \(detail)"
            case .apiError(let code, let message):
                return "GitHub API error (\(code)): \(message)"
            case .decodingError(let detail):
                return "Failed to decode response: \(detail)"
            case .cloneFailed(let detail):
                return "Git clone failed: \(detail)"
            case .invalidResponse:
                return "Received an invalid response from GitHub."
            }
        }
    }

    // MARK: - Keychain Constants

    private let keychainService = "com.claudework.github"
    private let keychainAccount = "access_token"

    // MARK: - Device Flow OAuth

    /// Start the GitHub Device Flow by requesting a device code.
    func startDeviceFlow() async throws -> DeviceCodeResponse {
        let url = URL(string: "https://github.com/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "scope": "repo,read:org"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GitHubError.apiError(statusCode, body)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DeviceCodeResponse.self, from: data)
        } catch {
            throw GitHubError.decodingError(error.localizedDescription)
        }
    }

    /// Poll GitHub for an access token after the user has entered their device code.
    ///
    /// - Parameters:
    ///   - deviceCode: The device code from `startDeviceFlow()`.
    ///   - interval: The minimum polling interval in seconds.
    /// - Returns: The access token string.
    func pollForToken(deviceCode: String, interval: Int) async throws -> String {
        var currentInterval = interval
        let maxAttempts = 60 // 최대 60회 시도 (~5분)
        var attempts = 0

        let url = URL(string: "https://github.com/login/oauth/access_token")!

        while attempts < maxAttempts {
            attempts += 1
            try await Task.sleep(nanoseconds: UInt64(currentInterval) * 1_000_000_000)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "client_id": clientId,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseBody = String(data: data, encoding: .utf8) ?? "unknown"
                throw GitHubError.apiError(statusCode, responseBody)
            }

            // Try to decode as a successful token response first.
            if let tokenResponse = try? JSONDecoder().decode(AccessTokenResponse.self, from: data),
               !tokenResponse.accessToken.isEmpty {
                self.accessToken = tokenResponse.accessToken
                try saveToken(tokenResponse.accessToken)
                return tokenResponse.accessToken
            }

            // Otherwise, check the error field for polling status.
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let errorCode = json["error"] as? String else {
                throw GitHubError.invalidResponse
            }

            switch errorCode {
            case "authorization_pending":
                // User hasn't authorized yet; keep polling.
                continue
            case "slow_down":
                // Increase interval by 5 seconds per spec.
                currentInterval += 5
                continue
            case "expired_token":
                throw GitHubError.deviceCodeExpired
            case "access_denied":
                throw GitHubError.accessDenied
            default:
                let description = json["error_description"] as? String ?? errorCode
                throw GitHubError.apiError(0, description)
            }
        }

        throw GitHubError.deviceCodeExpired
    }

    // MARK: - Token Management (Keychain)

    func saveToken(_ token: String) throws {
        // Delete any existing entry first.
        try? deleteToken()

        guard let tokenData = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed with status: \(status)")
            throw GitHubError.networkError("Failed to save token to Keychain (status: \(status))")
        }

        self.accessToken = token
        logger.info("GitHub token saved to Keychain.")
    }

    func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        self.accessToken = token
        return token
    }

    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed with status: \(status)")
            throw GitHubError.networkError("Failed to delete token from Keychain (status: \(status))")
        }

        self.accessToken = nil
        self.currentUser = nil
        logger.info("GitHub token deleted from Keychain.")
    }

    // MARK: - API Calls

    func fetchUser() async throws -> GitHubUser {
        let user: GitHubUser = try await apiRequest(path: "/user")
        self.currentUser = user
        return user
    }

    func fetchRepos() async throws -> [GitHubRepo] {
        // 페이지네이션으로 모든 레포 가져오기 (조직 포함)
        var allRepos: [GitHubRepo] = []
        var page = 1
        while true {
            let repos: [GitHubRepo] = try await apiRequest(
                path: "/user/repos?per_page=100&sort=updated&affiliation=owner,collaborator,organization_member&page=\(page)"
            )
            allRepos.append(contentsOf: repos)
            if repos.count < 100 { break }
            page += 1
        }
        return allRepos
    }

    // MARK: - SSH Setup

    /// Generate or reuse an SSH key and return the public key contents.
    func setupSSH() async throws -> String {
        let exists = await sshKeyManager.keyExists
        if !exists {
            try await sshKeyManager.generateKey()
        }
        try await sshKeyManager.configureSSHConfig()
        try await sshKeyManager.addToKnownHosts()
        return try await sshKeyManager.readPublicKey()
    }

    /// Register the given public key with the authenticated GitHub user.
    func registerSSHKey(_ publicKey: String) async throws {
        let body = try JSONSerialization.data(
            withJSONObject: [
                "title": "ClaudeWork (\(Host.current().localizedName ?? "Mac"))",
                "key": publicKey
            ]
        )

        let _: SSHKeyResponse = try await apiRequest(
            path: "/user/keys",
            method: "POST",
            body: body
        )

        logger.info("SSH key registered with GitHub.")
    }

    // MARK: - Clone

    func cloneRepo(_ repo: GitHubRepo, to path: String) async throws {
        guard let token = accessToken else {
            throw GitHubError.noAccessToken
        }

        // HTTPS clone with token — SSH 설정 불필요
        let cloneURL = "https://x-access-token:\(token)@github.com/\(repo.fullName).git"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", cloneURL, path]
        process.environment = ProcessInfo.processInfo.environment

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: stderrData, encoding: .utf8) ?? "unknown error"
            throw GitHubError.cloneFailed(stderr)
        }

        logger.info("Cloned \(repo.fullName, privacy: .public) to \(path, privacy: .public)")
    }

    // MARK: - Private Helpers

    private func apiRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let token = accessToken else {
            throw GitHubError.noAccessToken
        }

        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw GitHubError.networkError("Invalid URL: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw GitHubError.apiError(httpResponse.statusCode, responseBody)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Internal Response Types

/// Minimal response type for POST /user/keys.
private struct SSHKeyResponse: Decodable {
    let id: Int
    let key: String
}
