import XCTest

final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testWatchlistRowOpensDetail() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.staticTexts["AAPL"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["AAPL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Kaufen"].exists)
    }

    func testSearchResultOpensDetail() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.openTab("Suchen")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Applied")
        let result = app.staticTexts["AMAT"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        result.tap()
        XCTAssertTrue(app.navigationBars["AMAT"].waitForExistence(timeout: 5))
    }

    func testSearchStarAddsToWatchlist() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.openTab("Suchen")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("AMD")
        let star = app.buttons["Zur Watchlist"].firstMatch
        XCTAssertTrue(star.waitForExistence(timeout: 8))
        star.tap()
        XCTAssertTrue(app.buttons["Von Watchlist entfernen"].firstMatch.waitForExistence(timeout: 3))
    }

    func testSettingsOpenAndClose() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.buttons["Einstellungen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
        app.buttons["Schließen"].tap()
        XCTAssertTrue(app.staticTexts["AAPL"].waitForExistence(timeout: 5))
    }
}
