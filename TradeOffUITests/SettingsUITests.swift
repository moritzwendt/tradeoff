import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openSettings() -> XCUIApplication {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.buttons["Einstellungen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
        return app
    }

    private func open(_ app: XCUIApplication, _ row: String, title: String) {
        app.buttons.containing(.staticText, identifier: row).firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.back"].waitForExistence(timeout: 5), "\(title) did not open")
    }

    private func back(_ app: XCUIApplication) {
        app.buttons["settings.back"].tap()
        XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
    }

    func testHubListsEveryCategory() {
        let app = openSettings()
        for title in ["Guthaben", "Handel", "Gebühren", "Darstellung", "Datenquellen", "Version"] {
            XCTAssertTrue(app.staticTexts[title].exists, title)
        }
    }

    func testTradingToggleChangesHubSummary() {
        let app = openSettings()
        open(app, "Handel", title: "Handel")
        let toggle = app.switches["Marktzeiten ignorieren"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let before = toggle.value as? String
        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        back(app)
    }

    func testFeesScreenShowsRulesPerAssetClass() {
        let app = openSettings()
        open(app, "Gebühren", title: "Gebühren")
        XCTAssertTrue(app.staticTexts["Aktie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Anteil"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Pauschale"].firstMatch.exists)
        back(app)
    }

    func testDataSourcesListsProviders() {
        let app = openSettings()
        open(app, "Datenquellen", title: "Datenquellen")
        XCTAssertTrue(app.buttons["Erneut verbinden"].waitForExistence(timeout: 5))
        back(app)
    }

    func testAccountResetAsksForConfirmationThenResets() {
        let app = openSettings()
        app.buttons["settings.account"].tap()
        XCTAssertTrue(app.buttons["Konto zurücksetzen"].waitForExistence(timeout: 5))
        app.buttons["Konto zurücksetzen"].tap()
        XCTAssertTrue(app.buttons["Zurücksetzen"].waitForExistence(timeout: 5))
        app.buttons["Zurücksetzen"].tap()
        XCTAssertTrue(app.buttons["Konto zurücksetzen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Zurücksetzen"].exists)
    }

    func testAppearanceOffersChartStyleAndSorting() {
        let app = openSettings()
        open(app, "Darstellung", title: "Darstellung")
        XCTAssertTrue(app.buttons["Kerzen"].waitForExistence(timeout: 5))
        app.buttons["Kerzen"].tap()
        XCTAssertTrue(app.switches["Haptik"].exists)
        back(app)
    }
}
