import Foundation

struct MockMarketDefinition: Codable, Sendable {
    struct Tick: Codable, Sendable {
        var intervalSeconds: Double
        var volatilityMultiplier: Double
    }

    var tick: Tick
    var instruments: [MockInstrumentDefinition]

    static func load(from bundle: Bundle = MockMarketDefinition.bundle) throws -> MockMarketDefinition {
        guard let url = bundle.url(forResource: "MockMarket", withExtension: "json") else {
            throw ProviderError.resourceMissing("MockMarket.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MockMarketDefinition.self, from: data)
    }

    static var bundle: Bundle {
        Bundle(for: BundleToken.self)
    }
}

struct MockInstrumentDefinition: Codable, Sendable, Identifiable {
    var symbol: String
    var name: String
    var assetClass: AssetClass
    var startPrice: Decimal
    var previousClose: Decimal
    var dailyVolatility: Double
    var dailyDrift: Double
    var spreadBps: Double
    var liquidityUSD: Decimal?
    var seed: UInt64

    var id: String { symbol }

    var instrument: Instrument {
        Instrument(
            id: Instrument.makeID(provider: .mock, symbol: symbol),
            symbol: symbol,
            name: name,
            assetClass: assetClass,
            provider: .mock,
            providerSymbol: symbol,
            currency: "USD"
        )
    }
}

private final class BundleToken {}
