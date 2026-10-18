import Foundation

struct AppConfig: Sendable {
    let finnhubAPIKey: String?

    init(bundle: Bundle = .main) {
        finnhubAPIKey = AppConfig.sanitized(bundle.object(forInfoDictionaryKey: "FinnhubAPIKey"))
    }

    init(finnhubAPIKey: String?) {
        self.finnhubAPIKey = finnhubAPIKey
    }

    static func sanitized(_ raw: Any?) -> String? {
        guard let text = raw as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
