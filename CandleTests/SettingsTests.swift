import Foundation
import Testing
@testable import Candle

@MainActor
struct SettingsTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "candle.tests.\(UUID().uuidString)") ?? .standard
    }

    @Test func valuesRoundTripThroughJSON() throws {
        var values = SettingsValues()
        values.startingBalance = TestSupport.decimal("12345.67")
        values.fees.crypto.percent = TestSupport.decimal("0.0025")
        values.chartStyle = .candles
        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode(SettingsValues.self, from: data)
        #expect(decoded == values)
    }

    @Test func missingKeysFallBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(SettingsValues.self, from: Data("{}".utf8))
        #expect(decoded == SettingsValues())
    }

    @Test func settingsPersistAcrossInstances() {
        let store = defaults()
        let first = AppSettings(defaults: store)
        first.values.startingBalance = 777
        first.values.ignoreMarketHours = false
        let second = AppSettings(defaults: store)
        #expect(second.values.startingBalance == 777)
        #expect(second.values.ignoreMarketHours == false)
    }

    @Test func executionModelReflectsSettings() {
        let settings = AppSettings(defaults: defaults())
        settings.values.maxQuoteAge = 5
        settings.values.ignoreMarketHours = false
        let model = settings.executionModel
        #expect(model.maxQuoteAge == 5)
        #expect(!model.ignoreMarketHours)
    }

    @Test func resetRestoresDefaults() {
        let settings = AppSettings(defaults: defaults())
        settings.values.startingBalance = 1
        settings.reset()
        #expect(settings.values == SettingsValues())
    }
}
