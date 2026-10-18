import Foundation

struct ProviderCapabilities: Equatable, Sendable {
    var hasRealBidAsk: Bool
    var hasHistory: Bool
    var hasLiquidity: Bool
    var isDelayed: Bool
    var requiresAPIKey: Bool
    var supportedAssetClasses: Set<AssetClass>
    var pollInterval: TimeInterval?
}

enum ProviderAvailability: Equatable, Sendable {
    case ready
    case missingAPIKey
    case notImplemented

    var title: String {
        switch self {
        case .ready: "Aktiv"
        case .missingAPIKey: "Kein Key"
        case .notImplemented: "Nicht verbunden"
        }
    }
}
