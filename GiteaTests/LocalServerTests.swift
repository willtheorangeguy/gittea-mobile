import XCTest
@testable import Gitea

/// Enabled by scripts/run-local-integration.py; skipped in normal offline test runs.
final class LocalServerTests: XCTestCase {
    func testRealOAuthExchangeAndRefresh() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/integration/client.json")
        guard let data = try? Data(contentsOf: fixtureURL) else { throw XCTSkip("Run the local integration harness to test OAuth.") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        let server = try APIClient.normalizeURL(fixture.server)
        let response = try await OAuthTransport().token(server: server, fields: ["client_id": fixture.oauthClientID, "code": fixture.oauthCode, "code_verifier": fixture.oauthVerifier, "redirect_uri": OAuthAttempt.callback, "grant_type": "authorization_code"])
        let credentials = try response.credentials(server: server, clientID: fixture.oauthClientID)
        let oauth = try XCTUnwrap(credentials.oauth)
        let expired = Credentials(server: credentials.server, token: credentials.token, oauth: .init(clientID: oauth.clientID, refreshToken: oauth.refreshToken, expiresAt: Date(timeIntervalSinceNow: -60)), sessionID: credentials.sessionID)
        let previous = try CredentialStore.load()
        defer { if let previous { try? CredentialStore.save(previous) } else { try? CredentialStore.clear() } }
        try CredentialStore.save(expired)
        let api = try APIClient(credentials: expired)
        let user: GiteaUser = try await api.get("user")
        XCTAssertEqual(user.login, "mobile-tester")
        let refreshed = try XCTUnwrap(CredentialStore.load())
        XCTAssertGreaterThan(refreshed.oauth!.expiresAt, Date())
        // Gitea can issue an identical signed refresh token within the same second.
        // The updated expiry above proves that the refresh response was persisted.
        XCTAssertFalse(refreshed.oauth?.refreshToken.isEmpty ?? true)
        XCTAssertEqual(refreshed.sessionID, credentials.sessionID)
        let repos: [Repository] = try await api.get("user/repos")
        XCTAssertTrue(repos.contains { $0.name == "mobile-integration" })
        try await api.mutate("user/starred/mobile-tester/mobile-integration", method: "PUT")
        try await api.mutate("user/starred/mobile-tester/mobile-integration", method: "DELETE")
    }
    @MainActor func testRealSelfHostedServer() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/integration/client.json")
        guard let data = try? Data(contentsOf: fixtureURL) else { throw XCTSkip("Run scripts/run-local-integration.py to start a disposable Gitea server.") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        let api = APIClient(baseURL: try APIClient.normalizeURL(fixture.server), token: fixture.token)
        let user: GiteaUser = try await api.get("user")
        XCTAssertEqual(user.login, "mobile-tester")
        let repositories: [Repository] = try await api.get("user/repos", query: APIClient.page(1))
        let repo = try XCTUnwrap(repositories.first { $0.name == "mobile-integration" })
        let organizations: [Organization] = try await api.get("user/orgs")
        XCTAssertEqual(organizations.first?.name, "mobile-studio")
        let contents: [RepositoryContent] = try await api.get(repo.path + "/contents")
        XCTAssertTrue(contents.contains { $0.name == "README.md" })
        let readme: RepositoryContent = try await api.get(repo.path + "/contents/README.md")
        XCTAssertNotNil(readme.decodedText)
        let nested: [RepositoryContent] = try await api.get(repo.path + "/contents/src", query: [.init(name: "ref", value: "feature/mobile")])
        XCTAssertEqual(nested.first?.name, "hello #?.swift")
        let source: RepositoryContent = try await api.get(repo.path + "/contents/src/" + APIClient.segment("hello #?.swift"), query: [.init(name: "ref", value: "feature/mobile")])
        XCTAssertTrue(source.decodedText?.contains("Hello") == true)
        let branches: [Branch] = try await api.get(repo.path + "/branches")
        XCTAssertTrue(branches.contains { $0.name == "feature/mobile" })
        let commits: [Commit] = try await api.get(repo.path + "/commits")
        XCTAssertFalse(commits.isEmpty)
        let releases: [Release] = try await api.get(repo.path + "/releases")
        XCTAssertEqual(releases.first?.tag_name, "v1.0.0")

        let starPath = "user/starred/mobile-tester/mobile-integration"
        try await api.mutate(starPath, method: "PUT")
        let starred = try await api.isStarred(repo)
        XCTAssertTrue(starred)
        try await api.mutate(starPath, method: "DELETE")
        let unstarred = try await api.isStarred(repo)
        XCTAssertFalse(unstarred)

        let issue: Issue = try await api.send(repo.path + "/issues", body: ["title": "Created from native iOS", "body": "**Hello** from the simulator."])
        let _: IssueComment = try await api.send(repo.path + "/issues/\(issue.number)/comments", body: ["body": "A native comment"])
        let comments: [IssueComment] = try await api.get(repo.path + "/issues/\(issue.number)/comments")
        XCTAssertEqual(comments.first?.body, "A native comment")
        try await api.mutate(repo.path + "/issues/\(issue.number)", method: "PATCH", body: ["state": "closed"])
        let closed: Issue = try await api.get(repo.path + "/issues/\(issue.number)")
        XCTAssertEqual(closed.state, "closed")
        try await api.mutate(repo.path + "/issues/\(issue.number)", method: "PATCH", body: ["state": "open"])
        // Avoid the asynchronous full-text index immediately after creating a new issue.
        let found: [Issue] = try await api.get("repos/issues/search", query: [.init(name: "type", value: "issues"), .init(name: "state", value: "open"), .init(name: "created", value: "true")])
        XCTAssertFalse(found.isEmpty)
        XCTAssertEqual(found.first?.repository?.full_name, repo.full_name)

        let createdPull: PullRequest = try await api.send(repo.path + "/pulls", body: ["title": "Native pull request", "head": "feature/mobile", "base": "main", "body": "Review the new file."])
        let files: [ChangedFile] = try await api.get(repo.path + "/pulls/\(createdPull.number)/files")
        XCTAssertFalse(files.isEmpty)
        let diff = try await api.data(repo.path + "/pulls/\(createdPull.number).diff")
        XCTAssertTrue(String(data: diff, encoding: .utf8)?.contains("+print") == true)
        let reviewer = APIClient(baseURL: try APIClient.normalizeURL(fixture.server), token: fixture.reviewerToken)
        let _: PullReview = try await reviewer.send(repo.path + "/pulls/\(createdPull.number)/reviews", body: ["event": "APPROVED", "body": "Looks good from iOS", "commit_id": createdPull.head?.sha ?? ""])
        let reviews: [PullReview] = try await api.get(repo.path + "/pulls/\(createdPull.number)/reviews")
        XCTAssertEqual(reviews.first?.state, "APPROVED")
        try await api.mutate(repo.path + "/pulls/\(createdPull.number)/merge", method: "POST", body: ["Do": "merge", "head_commit_id": createdPull.head?.sha ?? "", "delete_branch_after_merge": false])
        let merged: PullRequest = try await api.get(repo.path + "/pulls/\(createdPull.number)")
        XCTAssertEqual(merged.merged, true)
        let notifications: [NotificationThread] = try await api.get("notifications", query: [.init(name: "all", value: "true")])
        if let notification = notifications.first {
            try await api.mutate("notifications/threads/\(notification.id)", method: "PATCH", query: [.init(name: "to-status", value: "read")])
        }
        try await api.mutate("notifications", method: "PUT", query: [.init(name: "to-status", value: "read"), .init(name: "last_read_at", value: ISO8601DateFormatter().string(from: Date()))])

        // Keychain round-trip uses the disposable simulator test account only.
        let previous = try CredentialStore.load()
        defer { if let previous { try? CredentialStore.save(previous) } else { try? CredentialStore.clear() } }
        let session = AppSession()
        try await session.connect(server: fixture.server, token: fixture.token)
        XCTAssertEqual(try CredentialStore.load()?.server, fixture.server)
        XCTAssertEqual(session.user?.login, user.login)
        session.signOut()
        XCTAssertNil(try CredentialStore.load())
        XCTAssertNil(session.client)
    }
    private struct Fixture: Decodable {
        let server: String; let token: String; let reviewerToken: String
        let oauthClientID: String; let oauthCode: String; let oauthVerifier: String
    }
}
