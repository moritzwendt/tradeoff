import XCTest

final class ScreenshotUITests: XCTestCase {
    static let largeText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]

    override func setUp() {
        continueAfterFailure = true
    }

    func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tour(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(app.waitForMarkets())
        capture(app, "\(prefix)-markets")

        app.staticTexts["AAPL"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Kaufen"].waitForExistence(timeout: 5))
        capture(app, "\(prefix)-detail")

        app.buttons["Kaufen"].tap()
        XCTAssertTrue(app.buttons["Weiter"].waitForExistence(timeout: 5))
        capture(app, "\(prefix)-ticket-empty")

        for digit in "1250" {
            app.buttons[String(digit)].firstMatch.tap()
        }
        capture(app, "\(prefix)-ticket-amount")

        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Gesamtkosten"].waitForExistence(timeout: 5))
        capture(app, "\(prefix)-ticket-review")

        app.buttons["ticket.back"].tap()
        for _ in 0..<6 {
            app.buttons["Löschen"].firstMatch.tap()
        }
        for digit in "99999" {
            app.buttons[String(digit)].firstMatch.tap()
        }
        capture(app, "\(prefix)-ticket-error")
    }

    func testStandardTextTour() {
        let app = XCUIApplication.launchedForTesting()
        tour(app, prefix: "standard")
    }

    func testLargeTextTour() {
        let app = XCUIApplication.launchedForTesting(Self.largeText)
        tour(app, prefix: "large")
    }

    func testSlowLoadingTour() {
        let app = XCUIApplication.launchedForTesting(["-uitest-slow"])
        sleep(1)
        capture(app, "slow-markets-1s")
        XCTAssertTrue(app.waitForMarkets(timeout: 20))
        app.staticTexts["AAPL"].firstMatch.tap()
        capture(app, "slow-detail-immediate")
        sleep(2)
        capture(app, "slow-detail-2s")
    }

    func testOfflineTour() {
        let app = XCUIApplication.launchedForTesting(["-uitest-offline"])
        sleep(8)
        capture(app, "offline-markets")
    }
}

extension ScreenshotUITests {
    func testSettingsTour() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())
        app.buttons["Einstellungen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
        capture(app, "settings-hub")
        for (row, name) in [("Handel", "trading"), ("Gebühren", "fees"), ("Darstellung", "appearance"), ("Datenquellen", "sources")] {
            app.buttons.containing(.staticText, identifier: row).firstMatch.tap()
            XCTAssertTrue(app.buttons["settings.back"].waitForExistence(timeout: 5))
            capture(app, "settings-\(name)")
            app.buttons["settings.back"].tap()
            XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
        }
        app.buttons["settings.account"].tap()
        XCTAssertTrue(app.buttons["Konto zurücksetzen"].waitForExistence(timeout: 5))
        capture(app, "settings-account")
    }

    func testLargeTextSettingsTour() {
        let app = XCUIApplication.launchedForTesting(Self.largeText)
        XCTAssertTrue(app.waitForMarkets())
        app.buttons["Einstellungen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Datenquellen"].waitForExistence(timeout: 5))
        capture(app, "large-settings-hub")
        app.buttons.containing(.staticText, identifier: "Datenquellen").firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.back"].waitForExistence(timeout: 5))
        capture(app, "large-settings-sources")
    }
}

extension ScreenshotUITests {
    func testOtherTabsTour() {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.waitForMarkets())

        app.openTab("Portfolio")
        sleep(1)
        capture(app, "portfolio-empty")
        app.openTab("Verlauf")
        sleep(1)
        capture(app, "history-empty")

        app.openTab("Märkte")
        app.staticTexts["AAPL"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Kaufen"].waitForExistence(timeout: 5))
        app.buttons["Kaufen"].tap()
        for digit in "2500" {
            app.buttons[String(digit)].firstMatch.tap()
        }
        app.buttons["Weiter"].tap()
        app.buttons["AAPL kaufen bestätigen"].tap()
        XCTAssertTrue(app.staticTexts["Gekauft"].waitForExistence(timeout: 5))
        capture(app, "filled")
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.buttons["Verkaufen"].waitForExistence(timeout: 5))
        capture(app, "detail-with-position")
        app.swipeUp()
        capture(app, "detail-scrolled")
        app.navigationBars.buttons.firstMatch.tap()

        app.openTab("Portfolio")
        sleep(1)
        capture(app, "portfolio-position")
        app.openTab("Verlauf")
        sleep(1)
        capture(app, "history-fill")

        app.openTab("Suchen")
        sleep(1)
        capture(app, "search-empty")
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText("App")
        sleep(2)
        capture(app, "search-results")
        field.typeText("zzzzqq")
        sleep(2)
        capture(app, "search-none")
    }
}
