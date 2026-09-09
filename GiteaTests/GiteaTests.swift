import XCTest
@testable import Gitea

final class GiteaTests: XCTestCase {
    func testSelfHostedURLNormalization() throws {
        XCTAssertEqual(try APIClient.normalizeURL(" git.example.com/gitea/ ").absoluteString, "https://git.example.com/gitea")
        XCTAssertEqual(try APIClient.normalizeURL("https://git.example.com/gitea/api/v1/").absoluteString, "https://git.example.com/gitea")
        XCTAssertEqual(try APIClient.normalizeURL("http://192.168.1.42:3000").host, "192.168.1.42")
        XCTAssertNoThrow(try APIClient.normalizeURL("http://gitea.local:3000"))
        XCTAssertNoThrow(try APIClient.normalizeURL("http://localhost:3000"))
        XCTAssertNoThrow(try APIClient.normalizeURL("http://172.16.0.4:3000/gitea"))
        XCTAssertThrowsError(try APIClient.normalizeURL("http://git.example.com"))
        XCTAssertThrowsError(try APIClient.normalizeURL("http://192.168.evil.com"))
        XCTAssertThrowsError(try APIClient.normalizeURL("http://192.168.1.1.evil.com"))
        XCTAssertThrowsError(try APIClient.normalizeURL("HTTP://git.example.com"))
        XCTAssertThrowsError(try APIClient.normalizeURL("https://user:password@git.example.com"))
        XCTAssertThrowsError(try APIClient.normalizeURL("https://git.example.com?token=secret"))
        XCTAssertThrowsError(try APIClient.normalizeURL("file:///tmp/server"))
    }

    func testRequestKeepsSubpathAndEscapesNames() throws {
        let api = APIClient(baseURL: try APIClient.normalizeURL("https://git.example.com/gitea"), token: "test-token")
        let request = try api.makeRequest("repos/alex/project/contents/\(APIClient.segment("hello #?.swift"))", query: [.init(name: "ref", value: "feature/a&b")])
        XCTAssertEqual(request.url?.host, "git.example.com")
        XCTAssertTrue(request.url!.absoluteString.contains("/gitea/api/v1/repos/alex/project/contents/hello%20%23%3F.swift"))
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "feature/a&b")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token test-token")
        XCTAssertNil(request.httpBody)
        XCTAssertThrowsError(try api.makeRequest("https://evil.example/user"))
        XCTAssertThrowsError(try api.makeRequest("../user"))
    }

    func testJSONMutationAndEmptyResponse() async throws {
        let session = makeSession(status: 204, body: Data())
        let api = APIClient(baseURL: URL(string: "https://git.example.com")!, token: "test", session: session)
        let request = try api.makeRequest("repos/alex/project/issues/1/comments", method: "POST", body: ["body": "hello\nworld"])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: String], ["body": "hello\nworld"])
        try await api.mutate("user/starred/alex/project", method: "PUT")
    }

    func testServerErrorsAndMalformedResponse() async throws {
        let api = APIClient(baseURL: URL(string: "https://git.example.com")!, token: "test", session: makeSession(status: 403, body: Data("{\"message\":\"forbidden\"}".utf8)))
        do { let _: GiteaUser = try await api.get("user"); XCTFail("Expected permission error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("permission")) }
        let malformed = APIClient(baseURL: URL(string: "https://git.example.com")!, token: "test", session: makeSession(status: 200, body: Data("<html>Sign in</html>".utf8)))
        do { let _: GiteaUser = try await malformed.get("user"); XCTFail("Expected decoding error") }
        catch { XCTAssertTrue(error is DecodingError) }
    }

    func testDemoWritesStayInDemoAndCanBeReadBack() async throws {
        let api = APIClient(baseURL: URL(string: "https://demo.gitea.local")!, token: "", demo: DemoServer())
        let repo = DemoServer.repositories[0]
        let initialStar = try await api.isStarred(repo)
        XCTAssertFalse(initialStar)
        try await api.mutate("user/starred/studio/orbit", method: "PUT")
        let updatedStar = try await api.isStarred(repo)
        XCTAssertTrue(updatedStar)
        let issue: Issue = try await api.send(repo.path + "/issues", body: ["title": "Test issue", "body": "A real demo mutation"])
        XCTAssertEqual(issue.title, "Test issue")
        let comment: IssueComment = try await api.send(repo.path + "/issues/\(issue.number)/comments", body: ["body": "A comment"])
        let comments: [IssueComment] = try await api.get(repo.path + "/issues/\(issue.number)/comments")
        XCTAssertEqual(comments.first?.id, comment.id)
        try await api.mutate(repo.path + "/issues/\(issue.number)", method: "PATCH", body: ["state": "closed"])
        let closed: Issue = try await api.get(repo.path + "/issues/\(issue.number)")
        XCTAssertEqual(closed.state, "closed")
        try await api.mutate("notifications/threads/1", method: "PATCH")
        let notifications: [NotificationThread] = try await api.get("notifications")
        XCTAssertEqual(notifications.count, 2)
        XCTAssertEqual(notifications.first?.subject.number, 42)
        let nextPage: [Repository] = try await api.get("user/repos", query: APIClient.page(2))
        XCTAssertTrue(nextPage.isEmpty)
    }

    func testContentDecodingAndFractionalDates() throws {
        let content = RepositoryContent(name: "a.swift", path: "a.swift", type: "file", content: Data("let café = 1".utf8).base64EncodedString(), encoding: "base64")
        XCTAssertEqual(content.decodedText, "let café = 1")
        let binary = RepositoryContent(name: "a.bin", path: "a.bin", type: "file", content: Data([0, 1, 2]).base64EncodedString(), encoding: "base64")
        XCTAssertNil(binary.decodedText)
        XCTAssertNotNil(DateText.date("2026-09-08T12:00:00.123Z"))
        XCTAssertNotNil(DateText.date("2026-09-08T12:00:00Z"))
    }

    @MainActor func testPaginationDeduplicatesAndRetainsDataOnLoadMoreFailure() async {
        let model = PageModel<Branch>()
        await model.reload { _ in (0..<30).map { Branch(name: "branch-\($0)") } }
        XCTAssertTrue(model.hasMore)
        await model.next { _ in [Branch(name: "branch-29"), Branch(name: "branch-30")] }
        XCTAssertEqual(model.items.count, 31)
        XCTAssertFalse(model.hasMore)
        await model.reload { _ in throw GiteaError.invalidResponse }
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNotNil(model.error)
    }

    private func makeSession(status: Int, body: Data) -> URLSession {
        StubURLProtocol.responseStatus = status
        StubURLProtocol.responseBody = body
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

final class StubURLProtocol: URLProtocol {
    static var responseStatus = 200
    static var responseBody = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseStatus, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
