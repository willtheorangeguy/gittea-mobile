import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

enum OAuthError: LocalizedError {
    case invalidCallback, rejected, cancelled, invalidClient, expiredSession, invalidToken, failed(String)
    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "The sign-in response couldn’t be verified. Please start sign-in again."
        case .rejected: return "Access wasn’t approved on your Gitea server."
        case .cancelled: return "Sign-in was cancelled."
        case .invalidClient: return "Enter the client ID of a public OAuth application registered on this Gitea server."
        case .expiredSession: return "Your Gitea authorization has expired. Connect your account again."
        case .invalidToken: return "The server returned an invalid OAuth token response."
        case .failed(let message): return message
        }
    }
}

struct OAuthAttempt {
    static let callback = "giteamobile://oauth/callback"
    static let scopes = "write:user read:organization write:repository write:issue write:notification"
    let server: URL
    let clientID: String
    let verifier: String
    let state: String

    init(server: URL, clientID: String) throws {
        let clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else { throw OAuthError.invalidClient }
        self.server = server
        self.clientID = clientID
        verifier = try Self.randomSecret()
        state = try Self.randomSecret()
    }
    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    private static func randomSecret() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw OAuthError.failed("Couldn’t create a secure sign-in request.") }
        return base64URL(Data(bytes))
    }
    var authorizationURL: URL {
        var parts = URLComponents(url: server.appendingPathComponent("login/oauth/authorize"), resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: Self.callback),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: Self.scopes),
            .init(name: "state", value: state), .init(name: "code_challenge", value: Self.challenge(verifier)),
            .init(name: "code_challenge_method", value: "S256")
        ]
        return parts.url!
    }
    func code(from callback: URL) throws -> String {
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              parts.scheme == "giteamobile", parts.host == "oauth", parts.path == "/callback",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil else { throw OAuthError.invalidCallback }
        let items = parts.queryItems ?? []
        // Reject ambiguous duplicate parameters, including duplicate state/code values.
        guard Set(items.map(\.name)).count == items.count,
              items.first(where: { $0.name == "state" })?.value == state else { throw OAuthError.invalidCallback }
        if items.contains(where: { $0.name == "error" }) { throw OAuthError.rejected }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else { throw OAuthError.invalidCallback }
        return code
    }
}

struct OAuthTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: TimeInterval
    let refresh_token: String?

    func credentials(server: URL, clientID: String, sessionID: UUID = UUID(), previousRefreshToken: String? = nil) throws -> Credentials {
        guard token_type.lowercased() == "bearer", !access_token.isEmpty, expires_in > 0,
              let refresh = refresh_token ?? previousRefreshToken, !refresh.isEmpty else { throw OAuthError.invalidToken }
        return Credentials(server: server.absoluteString, token: access_token,
                           oauth: .init(clientID: clientID, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expires_in)), sessionID: sessionID)
    }
}

struct OAuthTransport {
    let session: URLSession
    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.httpShouldSetCookies = false
        self.session = session ?? URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }
    func exchange(_ attempt: OAuthAttempt, code: String) async throws -> Credentials {
        let response = try await token(server: attempt.server, fields: ["client_id": attempt.clientID, "code": code,
            "grant_type": "authorization_code", "redirect_uri": OAuthAttempt.callback, "code_verifier": attempt.verifier])
        return try response.credentials(server: attempt.server, clientID: attempt.clientID)
    }
    func refresh(_ credentials: Credentials) async throws -> Credentials {
        guard let oauth = credentials.oauth else { throw OAuthError.expiredSession }
        let server = try APIClient.normalizeURL(credentials.server)
        let response = try await token(server: server, fields: ["client_id": oauth.clientID, "refresh_token": oauth.refreshToken, "grant_type": "refresh_token"])
        return try response.credentials(server: server, clientID: oauth.clientID, sessionID: credentials.sessionID ?? UUID(), previousRefreshToken: oauth.refreshToken)
    }
    func token(server: URL, fields: [String: String]) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: server.appendingPathComponent("login/oauth/access_token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data(fields.sorted { $0.key < $1.key }.map { APIClient.segment($0.key) + "=" + APIClient.segment($0.value) }.joined(separator: "&").utf8)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw GiteaError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            // Do not surface arbitrary token endpoint bodies, which may contain secrets.
            let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            if ["invalid_client", "unauthorized_client"].contains(code ?? "") { throw OAuthError.invalidClient }
            if [400, 401].contains(response.statusCode) { throw OAuthError.expiredSession }
            throw OAuthError.failed("OAuth sign-in failed (HTTP \(response.statusCode)). Check your server’s public client registration and callback URL.")
        }
        guard let token = try? JSONDecoder().decode(OAuthTokenResponse.self, from: data) else { throw OAuthError.invalidToken }
        return token
    }
}

/// Serializes refreshes, including simultaneous requests with an expired access token.
actor OAuthAuthorization {
    private var credentials: Credentials
    private let transport: OAuthTransport
    private let persist: @Sendable (Credentials, Credentials) throws -> Void
    private var flight: (id: UUID, task: Task<Credentials, Error>)?
    private var invalidated = false

    init(credentials: Credentials, transport: OAuthTransport = OAuthTransport(),
         persist: @escaping @Sendable (Credentials, Credentials) throws -> Void = { try CredentialStore.replace($0, with: $1) }) {
        self.credentials = credentials
        self.transport = transport
        self.persist = persist
    }
    func header(rejected: String? = nil) async throws -> String {
        guard !invalidated else { throw OAuthError.expiredSession }
        let current = "Bearer " + credentials.token
        // Another request may already have replaced the rejected token.
        if let rejected, rejected != current { return current }
        guard let oauth = credentials.oauth else { throw OAuthError.expiredSession }
        if rejected == nil && oauth.expiresAt.timeIntervalSinceNow > 30 { return current }
        let active: (id: UUID, task: Task<Credentials, Error>)
        if let flight { active = flight }
        else {
            let previous = credentials
            let transport = transport
            let persist = persist
            active = (UUID(), Task {
                let updated = try await transport.refresh(previous)
                try Task.checkCancellation()
                try persist(previous, updated)
                return updated
            })
            flight = active
        }
        defer { if flight?.id == active.id { flight = nil } }
        let updated = try await active.task.value
        guard !invalidated else { throw OAuthError.expiredSession }
        credentials = updated
        return "Bearer " + updated.token
    }
    func invalidate() { invalidated = true; flight?.task.cancel(); flight = nil }
}

@MainActor final class OAuthBrowser: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    func signIn(server: URL, clientID: String) async throws -> Credentials {
        guard session == nil else { throw OAuthError.failed("A sign-in is already in progress.") }
        let attempt = try OAuthAttempt(server: server, clientID: clientID)
        defer { session = nil }
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let browser = ASWebAuthenticationSession(url: attempt.authorizationURL, callbackURLScheme: "giteamobile") { url, error in
                if let url { continuation.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { continuation.resume(throwing: OAuthError.cancelled) }
                else { continuation.resume(throwing: OAuthError.failed("The sign-in browser couldn’t finish. Please try again.")) }
            }
            browser.presentationContextProvider = self
            browser.prefersEphemeralWebBrowserSession = true
            session = browser
            if !browser.start() { continuation.resume(throwing: OAuthError.failed("The sign-in browser couldn’t open.")) }
        }
        // Keep the browser retained until completion, and release it on every exit path.
        return try await OAuthTransport().exchange(attempt, code: attempt.code(from: callback))
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
    func cancel() { session?.cancel() }
}
