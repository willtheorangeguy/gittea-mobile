import XCTest

final class GiteaUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--demo"]
        app.launch()
    }

    func testHomeRepositoryAndCodeBrowsing() {
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 10))
        app.buttons["Repositories"].firstMatch.tap()
        let orbit = app.staticTexts["orbit"].firstMatch
        XCTAssertTrue(orbit.waitForExistence(timeout: 5))
        orbit.tap()
        XCTAssertTrue(app.buttons["starRepository"].waitForExistence(timeout: 5))
        app.buttons["starRepository"].tap()
        XCTAssertTrue(app.buttons["starRepository"].label.contains("Starred"))
        app.buttons["Code"].tap()
        app.staticTexts["README.md"].tap()
        XCTAssertTrue(app.staticTexts["A little space for big ideas."].waitForExistence(timeout: 5))
        app.buttons["Source"].tap()
        XCTAssertTrue(app.buttons["Preview"].exists)
        capture("Repository source")
    }

    func testCreateIssueAndComment() {
        app.buttons["Repositories"].firstMatch.tap()
        app.staticTexts["orbit"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Issues'")).firstMatch.tap()
        app.buttons["New issue"].tap()
        let title = app.textFields["workTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("An issue from the iPhone")
        app.buttons["createWork"].tap()
        let issue = app.staticTexts["An issue from the iPhone"]
        XCTAssertTrue(issue.waitForExistence(timeout: 5)); issue.tap()
        for _ in 0..<5 { if app.buttons["addComment"].isHittable { break }; app.swipeUp() }
        app.buttons["addComment"].tap()
        let body = app.textViews["commentBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 5)); body.tap(); body.typeText("This works from the simulator.")
        app.buttons["sendComment"].tap()
        XCTAssertTrue(app.staticTexts["This works from the simulator."].waitForExistence(timeout: 5))
        capture("Issue conversation")
    }

    func testNotificationsAndProfile() {
        app.tabBars.buttons["Notifications"].tap()
        XCTAssertTrue(app.staticTexts["A fresh look for the project overview"].waitForExistence(timeout: 5))
        app.buttons["Mark all as read"].tap()
        XCTAssertTrue(app.staticTexts["You’re all caught up"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 5))
        capture("Profile")
    }

    func testOnboardingAndDemoEntry() {
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.textFields["serverURL"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["connectButton"].isEnabled)
        app.swipeUp()
        app.buttons["demoButton"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        capture("Home")
    }

    func testPullRequestDiffReviewAndMerge() {
        app.buttons["Pull requests"].firstMatch.tap()
        let title = app.staticTexts["A fresh look for the project overview"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        app.buttons["Files changed"].tap()
        XCTAssertTrue(app.staticTexts["src/components/ProjectCard.tsx"].waitForExistence(timeout: 5))
        app.buttons["Read unified diff"].tap()
        XCTAssertTrue(app.staticTexts["+      <h2>{project.name}</h2>"].waitForExistence(timeout: 5))
        capture("Pull request diff")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Review changes"].tap()
        app.buttons["Approve"].tap()
        app.buttons["Submit"].tap()
        XCTAssertTrue(app.buttons["Merge pull request"].waitForExistence(timeout: 5))
        app.buttons["Merge pull request"].tap()
        app.buttons["Confirm merge"].tap()
        XCTAssertTrue(app.staticTexts["Merged"].waitForExistence(timeout: 5))
        capture("Merged pull request")
    }

    func testExploreSearchAndBranchSwitch() {
        app.tabBars.buttons["Explore"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("homelab")
        XCTAssertTrue(app.staticTexts["homelab"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["homelab"].firstMatch.tap()
        app.buttons["Code"].tap()
        app.buttons["branchPicker"].tap()
        app.buttons["develop"].tap()
        XCTAssertTrue(app.buttons["branchPicker"].label.contains("develop"))
    }

    func testOAuthSetupKeepsServerAndHidesTokenField() {
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Browser sign-in"].tap()
        XCTAssertTrue(app.textFields["serverURL"].exists)
        XCTAssertTrue(app.textFields["oauthClientID"].exists)
        XCTAssertFalse(app.secureTextFields["accessToken"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["giteamobile://oauth/callback"].exists)
        XCTAssertFalse(app.buttons["connectButton"].isEnabled)
        capture("OAuth setup")
    }

    func testDeviceAlertsExplainsDemoAndDeliveryLimits() {
        app.tabBars.buttons["Profile"].tap()
        for _ in 0..<4 { if app.buttons["Device alerts"].isHittable { break }; app.swipeUp() }
        app.buttons["Device alerts"].tap()
        XCTAssertTrue(app.staticTexts["Connect your Gitea server to enable device alerts."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["notificationChecks"].isEnabled)
        capture("Device alerts")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
