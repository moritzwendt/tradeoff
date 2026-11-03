import XCTest

extension XCUIApplication {
    static func launchedForTesting(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-ignore-hours"] + extra
        app.launch()
        return app
    }

    func waitForMarkets(timeout: TimeInterval = 12) -> Bool {
        staticTexts["AAPL"].waitForExistence(timeout: timeout)
    }

    func openTab(_ name: String) {
        tabBars.buttons[name].tap()
    }
}
