import XCTest
@testable import Gitea

final class OAuthTests: XCTestCase {
    func testPKCEKnownVectorAndCallbackValidation() throws {
        XCTAssertEqual(OAuthAttempt.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let attempt = try OAuthAttempt(server: APIClient.normalizeURL("https://git.example.com/gitea"), clientID: "client")
        XCTAssertEqual(attempt.verifier.count, 43)
        XCTAssertNotEqual(attempt.verifier, attempt.state)
        XCTAssertEqual(attempt.authorizationURL.path, "/gitea/login/oauth/authorize")
        let query = URLComponents(url: attempt.authorizationURL, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "code_challenge_method" }?.value, "S256")
        XCTAssertFalse(query.contains { $0.name == "client_secret" || $0.name == "code_verifier" })
        XCTAssertEqual(try attempt.code(from: URL(string: OAuthAttempt.callback + "?code=hello&state=" + attempt.state)!), "hello")
        for url in [OAuthAttempt.callback + "?code=hello&state=wrong", "giteamobile://evil/callback?code=hello&state=" + attempt.state,
                    OAuthAttempt.callback + "?code=hello&state=\(attempt.state)&state=\(attempt.state)", OAuthAttempt.callback + "?state=" + attempt.state,
                    OAuthAttempt.callback + "?code=hello&state=\(attempt.state)#fragment"] {
            XCTAssertThrowsError(try attempt.code(from: URL(string: url)!))
        }
        XCTAssertThrowsError(try attempt.code(from: URL(string: OAuthAttempt.callback + "?error=access_denied&state=" + attempt.state)!))
    }

    func testExistingTokenCredentialsRemainDecodable() throws {
        let old = try JSONDecoder().decode(Credentials.self, from: Data("{\"server\":\"https://git.example.com\",\"token\":\"personal\"}".utf8))
        XCTAssertNil(old.oauth)
        XCTAssertNil(old.sessionID)
    }

    func testExchangeUsesPublicClientAndPreservesSubpath() async throws {
        let log = RequestLog()
        let transport = OAuthTransport(session: stub { request in
            log.record(request)
            return (200, Self.tokenResponse)
        })
        let attempt = try OAuthAttempt(server: APIClient.normalizeURL("https://git.example.com/gitea"), clientID: "client + id")
        let credentials = try await transport.exchange(attempt, code: "code&+value")
        XCTAssertEqual(credentials.oauth?.clientID, "client + id")
        XCTAssertEqual(credentials.oauth?.refreshToken, "rotated-refresh")
        let request = try XCTUnwrap(log.requests.first)
        XCTAssertEqual(request.url?.path, "/gitea/login/oauth/access_token")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = RequestLog.body(request)
        XCTAssertTrue(body.contains("code=code%26%2Bvalue"))
        XCTAssertTrue(body.contains("code_verifier=" + attempt.verifier))
        XCTAssertFalse(body.contains("client_secret"))
    }

    func testConcurrentRequestsShareOneRefresh() async throws {
        let log = RequestLog()
        let transport = OAuthTransport(session: stub { request in log.record(request); return (200, Self.tokenResponse) })
        let authorization = OAuthAuthorization(credentials: credentials(expired: true), transport: transport, persist: { _, _ in log.didPersist() })
        let values = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<20 { group.addTask { try await authorization.header() } }
            var headers: [String] = []
            for try await value in group { headers.append(value) }
            return headers
        }
        XCTAssertEqual(Set(values), ["Bearer new-access"])
        XCTAssertEqual(log.requests.count, 1)
        XCTAssertEqual(log.persistCount, 1)
        XCTAssertTrue(RequestLog.body(log.requests[0]).contains("refresh_token=old-refresh"))
    }

    func testUnauthorizedRequestRefreshesOnceAndRetainsMutationBody() async throws {
        let log = RequestLog()
        let session = stub { request in
            log.record(request)
            if request.url?.path.hasSuffix("access_token") == true { return (200, Self.tokenResponse) }
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access" ? (204, Data()) : (401, Data())
        }
        let authorization = OAuthAuthorization(credentials: credentials(expired: false), transport: OAuthTransport(session: session), persist: { _, _ in log.didPersist() })
        let api = APIClient(baseURL: URL(string: "https://git.example.com")!, token: "unused", session: session, authorization: authorization)
        try await api.mutate("repos/alex/demo/issues/1/comments", method: "POST", body: ["body": "hello"])
        XCTAssertEqual(log.requests.count, 3)
        XCTAssertEqual(RequestLog.body(log.requests[0]), RequestLog.body(log.requests[2]))
        XCTAssertEqual(log.requests[2].httpMethod, "POST")
        XCTAssertEqual(log.persistCount, 1)
    }

    func testRejectedRefreshDoesNotOverwriteCredentials() async throws {
        let log = RequestLog()
        let transport = OAuthTransport(session: stub { _ in (400, Data("{\"error\":\"invalid_grant\"}".utf8)) })
        let authorization = OAuthAuthorization(credentials: credentials(expired: true), transport: transport, persist: { _, _ in log.didPersist() })
        do { _ = try await authorization.header(); XCTFail("Expected expired authorization") }
        catch { XCTAssertTrue(error is OAuthError) }
        XCTAssertEqual(log.persistCount, 0)
    }

    func testLateRefreshCannotRestoreSignedOutAccount() throws {
        let previous = try CredentialStore.load()
        defer { if let previous { try? CredentialStore.save(previous) } else { try? CredentialStore.clear() } }
        let original = credentials(expired: true)
        try CredentialStore.save(original)
        try CredentialStore.clear()
        XCTAssertThrowsError(try CredentialStore.replace(original, with: credentials(expired: false)))
        XCTAssertNil(try CredentialStore.load())
        let other = Credentials(server: "https://another.example.com", token: "other", sessionID: UUID())
        try CredentialStore.save(other)
        XCTAssertThrowsError(try CredentialStore.replace(original, with: credentials(expired: false)))
        XCTAssertEqual(try CredentialStore.load(), other)
    }

    private func credentials(expired: Bool) -> Credentials {
        Credentials(server: "https://git.example.com", token: "old-access", oauth: .init(clientID: "client", refreshToken: "old-refresh", expiresAt: Date(timeIntervalSinceNow: expired ? -10 : 3600)), sessionID: UUID())
    }
    private static let tokenResponse = Data("{\"access_token\":\"new-access\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"refresh_token\":\"rotated-refresh\"}".utf8)
    private func stub(_ handler: @escaping (URLRequest) -> (Int, Data)) -> URLSession {
        OAuthURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OAuthURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URLRequest] = []
    private var persisted = 0
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return stored }
    var persistCount: Int { lock.lock(); defer { lock.unlock() }; return persisted }
    func record(_ request: URLRequest) {
        // URLProtocol may expose a body stream; normalize it for assertions.
        var request = request
        if request.httpBody == nil { request.httpBody = Data(Self.body(request).utf8) }
        lock.lock(); defer { lock.unlock() }; stored.append(request)
    }
    func didPersist() { lock.lock(); defer { lock.unlock() }; persisted += 1 }
    static func body(_ request: URLRequest) -> String {
        if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return String(decoding: data, as: UTF8.self)
    }
}

final class OAuthURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
