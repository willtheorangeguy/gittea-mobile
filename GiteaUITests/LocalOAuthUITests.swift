import XCTest

final class LocalOAuthUITests: XCTestCase {
    /// The harness uses a disposable simulator so the test never replaces a real account.
    func testBrowserSignInRestorationAndNotificationOptIn() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/integration/client.json")
        guard let data = try? Data(contentsOf: fixtureURL) else { throw XCTSkip("Run the local integration harness with --ui.") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: data)
        guard let expectedDevice = fixture.uiSimulatorID,
              ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == expectedDevice else {
            throw XCTSkip("OAuth UI integration runs only on the harness's disposable simulator.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["Browser sign-in"].waitForExistence(timeout: 10))
        app.buttons["Browser sign-in"].tap()
        let server = app.textFields["serverURL"]
        server.tap(); server.typeText(fixture.server)
        let client = app.textFields["oauthClientID"]
        client.tap(); client.typeText(fixture.oauthClientID)
        app.swipeUp()
        app.buttons["connectButton"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if app.alerts.buttons["Continue"].waitForExistence(timeout: 2) { app.alerts.buttons["Continue"].tap() }
        else if springboard.alerts.buttons["Continue"].exists { springboard.alerts.buttons["Continue"].tap() }
        let username = app.webViews.textFields.firstMatch
        XCTAssertTrue(username.waitForExistence(timeout: 20))
        username.tap(); username.typeText("mobile-tester")
        let password = app.webViews.secureTextFields.firstMatch
        password.tap(); password.typeText(fixture.password)
        app.webViews.buttons["Sign In"].tap()
        let approve = app.webViews.buttons["Authorize Application"]
        if approve.waitForExistence(timeout: 4) { approve.tap() }
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 20))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 20), "OAuth credentials should restore from Keychain")
        XCTAssertTrue(app.staticTexts["mobile-integration"].firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        for _ in 0..<4 { if app.buttons["Device alerts"].isHittable { break }; app.swipeUp() }
        app.buttons["Device alerts"].tap()
        app.switches["notificationChecks"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        if springboard.alerts.buttons["Allow"].waitForExistence(timeout: 5) { springboard.alerts.buttons["Allow"].tap() }
        else if app.alerts.buttons["Allow"].exists { app.alerts.buttons["Allow"].tap() }
        let checked = app.descendants(matching: .any)["lastNotificationCheck"].firstMatch.waitForExistence(timeout: 15)
        XCTAssertTrue(checked, "Alert settings: " + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Real OAuth and notification opt-in"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.switches["notificationChecks"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["Check now"].isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<4 { if app.buttons["signOut"].isHittable { break }; app.swipeUp() }
        app.buttons["signOut"].tap()
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 5))
    }
    private struct Fixture: Decodable { let server: String; let oauthClientID: String; let password: String; let uiSimulatorID: String? }
}
