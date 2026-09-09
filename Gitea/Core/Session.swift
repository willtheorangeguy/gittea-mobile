import SwiftUI
import Security

struct Credentials: Codable, Equatable {
    let server: String
    let token: String
    var oauth: OAuthGrant? = nil
    var sessionID: UUID? = nil
    struct OAuthGrant: Codable, Equatable {
        let clientID: String
        let refreshToken: String
        let expiresAt: Date
    }
}

enum CredentialStore {
    private static let lock = NSRecursiveLock()
    private static let service = "app.gitea.mobile.credentials"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "current"]
    }
    static func save(_ credentials: Credentials) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw GiteaError.keychain(added) }
        } else if status != errSecSuccess { throw GiteaError.keychain(status) }
    }
    static func load() throws -> Credentials? {
        lock.lock(); defer { lock.unlock() }
        var item = query
        item[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw GiteaError.keychain(status) }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }
    static func clear() throws {
        lock.lock(); defer { lock.unlock() }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw GiteaError.keychain(status) }
    }
    static func replace(_ previous: Credentials, with updated: Credentials) throws {
        lock.lock(); defer { lock.unlock() }
        // A late refresh must never restore credentials after sign-out or replace a new account.
        guard try load() == previous else { throw OAuthError.expiredSession }
        try save(updated)
    }
    static func allowBackgroundAccess(_ allowed: Bool) throws {
        lock.lock(); defer { lock.unlock() }
        let accessibility = allowed ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemUpdate(query as CFDictionary, [kSecAttrAccessible as String: accessibility] as CFDictionary)
        guard status == errSecSuccess else { throw GiteaError.keychain(status) }
    }
}

@MainActor final class AppSession: ObservableObject {
    @Published var client: APIClient?
    @Published var user: GiteaUser?
    @Published var restoring = true
    @Published var error: String?
    @Published var repositories: [Repository] = []
    @Published var notifications: [NotificationThread] = []
    @Published var accountGeneration = UUID()
    private var restoreTask: Task<Void, Never>?
    var isDemo: Bool { client?.isDemo == true }
    var unreadCount: Int { notifications.filter(\.unread).count }

    func restore() async {
        if let restoreTask { await restoreTask.value; return }
        let task = Task { await self.performRestore() }
        restoreTask = task
        await task.value
    }
    private func performRestore() async {
        defer { restoring = false }
        if ProcessInfo.processInfo.arguments.contains("--demo") { enterDemo(); return }
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
        do {
            if let credentials = try CredentialStore.load() {
                try await connect(credentials: credentials, save: false)
            }
        } catch { self.error = error.localizedDescription }
    }
    func connect(server: String, token: String, save: Bool = true) async throws {
        let url = try APIClient.normalizeURL(server)
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GiteaError.server(401, "Enter an access token.") }
        try await connect(credentials: Credentials(server: url.absoluteString, token: trimmed, sessionID: UUID()), save: save)
    }
    func connect(credentials: Credentials, save: Bool = true) async throws {
        let api = try APIClient(credentials: credentials)
        let user: GiteaUser = try await api.get("user")
        if save {
            try CredentialStore.save(credentials)
            // A new connection starts with alerts off and credentials available only while unlocked.
            try CredentialStore.allowBackgroundAccess(false)
            NotificationService.shared.reset()
        }
        accountGeneration = UUID()
        self.user = user
        self.client = api
        self.error = nil
    }
    func enterDemo() {
        accountGeneration = UUID()
        user = DemoServer.user
        client = APIClient(baseURL: URL(string: "https://demo.gitea.local")!, token: "", demo: DemoServer())
        repositories = []
        notifications = []
        error = nil
    }
    func signOut() {
        do { if !isDemo { try CredentialStore.clear() } }
        catch { self.error = error.localizedDescription; return }
        if let authorization = client?.authorization { Task { await authorization.invalidate() } }
        if !isDemo { NotificationService.shared.reset() }
        accountGeneration = UUID()
        client = nil
        user = nil
        repositories = []
        notifications = []
        error = nil
    }
}
