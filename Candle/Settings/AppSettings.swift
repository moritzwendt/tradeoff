import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private var storage: SettingsValues
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "candle.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(SettingsValues.self, from: data) {
            storage = decoded
        } else {
            storage = SettingsValues()
        }
    }

    var values: SettingsValues {
        get {
            access(keyPath: \.values)
            return storage
        }
        set {
            withMutation(keyPath: \.values) {
                storage = newValue
                persist()
            }
        }
    }

    var executionModel: ExecutionModel {
        ExecutionModel(
            fees: values.fees,
            maxQuoteAge: values.maxQuoteAge,
            minimumNotional: 1,
            ignoreMarketHours: values.ignoreMarketHours
        )
    }

    func reset() {
        values = SettingsValues()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(storage) {
            defaults.set(data, forKey: key)
        }
    }
}
