import XCTest
@testable import Gitea

final class NotificationTests: XCTestCase {
    func testInitialBaselineDoesNotAlertAndUpdatesDeduplicate() throws {
        var ledger = NotificationLedger()
        var first = thread(id: 1, timestamp: "2026-09-08T10:00:00Z")
        XCTAssertTrue(ledger.changes(in: [first]).isEmpty)
        ledger.record([first])
        XCTAssertTrue(ledger.changes(in: [first]).isEmpty)
        first.updated_at = "2026-09-08T11:00:00Z"
        let second = thread(id: 2, timestamp: "2026-09-08T12:00:00Z")
        XCTAssertEqual(ledger.changes(in: [first, second]).map(\.id), [1, 2])
        ledger.record([first, second])
        let restored = try JSONDecoder().decode(NotificationLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertTrue(restored.changes(in: [first, second]).isEmpty)
        first.unread = false
        first.updated_at = "2026-09-08T13:00:00Z"
        XCTAssertTrue(restored.changes(in: [first]).isEmpty)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(ledger), as: UTF8.self).contains("Private title"))
    }
    func testAccountKeysSeparateInstancesAndUsers() {
        let first = NotificationLedger.accountKey(server: "https://git.example.com/one", login: "alex")
        XCTAssertNotEqual(first, NotificationLedger.accountKey(server: "https://git.example.com/two", login: "alex"))
        XCTAssertNotEqual(first, NotificationLedger.accountKey(server: "https://git.example.com/one", login: "sarah"))
        XCTAssertEqual(first.count, 64)
    }
    private func thread(id: Int, timestamp: String) -> NotificationThread {
        NotificationThread(id: id, unread: true, updated_at: timestamp, repository: DemoServer.repositories[0], subject: .init(title: "Private title", type: "Issue"))
    }
}
