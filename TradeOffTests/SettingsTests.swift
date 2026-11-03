import Foundation
import Testing
@testable import TradeOff

@MainActor
struct SettingsTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
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

    @Test func marketHoursAreEnforcedByDefault() {
        #expect(SettingsValues().ignoreMarketHours == false)
        #expect(AppSettings(defaults: defaults()).executionModel.ignoreMarketHours == false)
    }

    @Test func legacyIgnoreMarketHoursIsResetOnce() throws {
        let store = defaults()
        var legacy = SettingsValues()
        legacy.ignoreMarketHours = true
        legacy.startingBalance = 4321
        store.set(try JSONEncoder().encode(legacy), forKey: "tradeoff.settings.v1")

        let first = AppSettings(defaults: store)
        #expect(first.values.ignoreMarketHours == false)
        #expect(first.values.startingBalance == 4321)

        first.values.ignoreMarketHours = true
        let second = AppSettings(defaults: store)
        #expect(second.values.ignoreMarketHours == true)
    }
}
