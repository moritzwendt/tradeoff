import Foundation

struct AppConfig: Sendable {
    let finnhubAPIKey: String?
    let alpacaKeyID: String?
    let alpacaSecretKey: String?

    init(bundle: Bundle = .main) {
        finnhubAPIKey = AppConfig.sanitized(bundle.object(forInfoDictionaryKey: "FinnhubAPIKey"))
        alpacaKeyID = AppConfig.sanitized(bundle.object(forInfoDictionaryKey: "AlpacaKeyID"))
        alpacaSecretKey = AppConfig.sanitized(bundle.object(forInfoDictionaryKey: "AlpacaSecretKey"))
    }

    init(finnhubAPIKey: String? = nil, alpacaKeyID: String? = nil, alpacaSecretKey: String? = nil) {
        self.finnhubAPIKey = finnhubAPIKey
        self.alpacaKeyID = alpacaKeyID
        self.alpacaSecretKey = alpacaSecretKey
    }

    static func sanitized(_ raw: Any?) -> String? {
        guard let text = raw as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
