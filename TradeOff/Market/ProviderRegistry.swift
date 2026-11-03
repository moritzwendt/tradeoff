import Foundation

struct ProviderRegistry: Sendable {
    let all: [any PriceProvider]
    private let storage: [ProviderID: any PriceProvider]

    init(_ providers: [any PriceProvider]) {
        all = providers
        storage = Dictionary(providers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func provider(for id: ProviderID) -> (any PriceProvider)? {
        storage[id]
    }

    func availability(for id: ProviderID) -> ProviderAvailability {
        storage[id]?.availability ?? .notImplemented
    }

    var activeAssetClasses: Set<AssetClass> {
        all
            .filter { $0.availability == .ready }
            .reduce(into: Set<AssetClass>()) { $0.formUnion($1.capabilities.supportedAssetClasses) }
    }
}
