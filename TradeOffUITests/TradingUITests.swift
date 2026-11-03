import XCTest

final class TradingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openTicket(_ app: XCUIApplication) {
        XCTAssertTrue(app.waitForMarkets())
        app.staticTexts["AAPL"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Kaufen"].waitForExistence(timeout: 5))
        app.buttons["Kaufen"].tap()
    }

    private func tapDigits(_ app: XCUIApplication, _ digits: String) {
        for digit in digits {
            app.buttons[String(digit)].firstMatch.tap()
        }
    }

    func testBuyFlowEditsReviewsAndConfirms() {
        let app = XCUIApplication.launchedForTesting()
        openTicket(app)
        XCTAssertTrue(app.buttons["Weiter"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Weiter"].isEnabled)
        tapDigits(app, "100")
        XCTAssertTrue(app.buttons["Weiter"].isEnabled)
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Gesamtkosten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Gebühr"].exists)
        XCTAssertTrue(app.staticTexts["Guthaben danach"].exists)
        app.buttons["AAPL kaufen bestätigen"].tap()
        XCTAssertTrue(app.staticTexts["Gekauft"].waitForExistence(timeout: 5))
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.buttons["Verkaufen"].waitForExistence(timeout: 5))
    }

    func testReviewCanGoBackToEditing() {
        let app = XCUIApplication.launchedForTesting()
        openTicket(app)
        tapDigits(app, "50")
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Gesamtkosten"].waitForExistence(timeout: 5))
        app.buttons["ticket.back"].tap()
        XCTAssertTrue(app.buttons["Weiter"].waitForExistence(timeout: 5))
    }

    func testTooLargeAmountShowsMessageAndBlocksReview() {
        let app = XCUIApplication.launchedForTesting()
        openTicket(app)
        tapDigits(app, "99999")
        XCTAssertTrue(app.staticTexts["Nicht genug Guthaben"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Weiter"].isEnabled)
    }
}
