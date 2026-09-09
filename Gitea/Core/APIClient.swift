import Foundation

/// Only sends credentials to the configured origin; redirects are deliberately rejected.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class APIClient {
    let baseURL: URL
    let isDemo: Bool
    private let token: String
    private let session: URLSession
    private let demo: DemoServer?
    let authorization: OAuthAuthorization?
    static let pageSize = 30

    init(baseURL: URL, token: String, session: URLSession? = nil, demo: DemoServer? = nil, authorization: OAuthAuthorization? = nil) {
        self.baseURL = baseURL
        self.token = token
        self.demo = demo
        self.isDemo = demo != nil
        self.authorization = authorization
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        self.session = session ?? URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }
    convenience init(credentials: Credentials) throws {
        self.init(baseURL: try Self.normalizeURL(credentials.server), token: credentials.token,
                  authorization: credentials.oauth == nil ? nil : OAuthAuthorization(credentials: credentials))
    }

    static func normalizeURL(_ input: String) throws -> URL {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://" + value }
        guard var parts = URLComponents(string: value), let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              ["https", "http"].contains(parts.scheme?.lowercased() ?? ""), !host.contains(" ") else { throw GiteaError.invalidURL }
        parts.scheme = parts.scheme?.lowercased()
        let normalizedHost = host.lowercased()
        let hostParts = normalizedHost.split(separator: ".", omittingEmptySubsequences: false)
        let octets = hostParts.compactMap { Int($0) }
        let privateIP = hostParts.count == 4 && octets.count == 4 && octets.allSatisfy { (0...255).contains($0) } &&
            (octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168) ||
             (octets[0] == 172 && (16...31).contains(octets[1])))
        let local = normalizedHost == "localhost" || normalizedHost == "[::1]" || normalizedHost == "::1" || normalizedHost.hasSuffix(".local") || privateIP
        if parts.scheme == "http" && !local { throw GiteaError.insecureURL }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        if parts.path.hasSuffix("/api/v1") { parts.path = String(parts.path.dropLast(7)) }
        guard let url = parts.url else { throw GiteaError.invalidURL }
        return url
    }

    static func segment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? value
    }

    func makeRequest(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: [String: Any]? = nil) throws -> URLRequest {
        // Paths are app-defined relative routes, never server-provided absolute URLs.
        guard !path.hasPrefix("/"), !path.contains("://"), !path.split(separator: "/").contains(".."),
              var parts = URLComponents(string: baseURL.absoluteString + "/api/v1/" + path) else { throw GiteaError.invalidURL }
        parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url else { throw GiteaError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func data(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: [String: Any]? = nil) async throws -> Data {
        try Task.checkCancellation()
        if let demo { return try await demo.respond(path: path, method: method, query: query, body: body) }
        var request = try makeRequest(path, method: method, query: query, body: body)
        if let authorization { request.setValue(try await authorization.header(), forHTTPHeaderField: "Authorization") }
        var (data, response) = try await session.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 401, let authorization {
            request.setValue(try await authorization.header(rejected: request.value(forHTTPHeaderField: "Authorization")), forHTTPHeaderField: "Authorization")
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request)
        }
        guard let response = response as? HTTPURLResponse else { throw GiteaError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw GiteaError.server(response.statusCode, message ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
        }
        return data
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try JSONDecoder().decode(T.self, from: await data(path, query: query))
    }
    func send<T: Decodable>(_ path: String, method: String = "POST", body: [String: Any]) async throws -> T {
        try JSONDecoder().decode(T.self, from: await data(path, method: method, body: body))
    }
    func mutate(_ path: String, method: String, query: [URLQueryItem] = [], body: [String: Any]? = nil) async throws {
        _ = try await data(path, method: method, query: query, body: body)
    }
    func isStarred(_ repo: Repository) async throws -> Bool {
        do { _ = try await data("user/starred/\(Self.segment(repo.owner.login))/\(Self.segment(repo.name))"); return true }
        catch GiteaError.server(404, _) { return false }
    }
    static func page(_ page: Int) -> [URLQueryItem] {
        [.init(name: "page", value: String(page)), .init(name: "limit", value: String(pageSize))]
    }
}
