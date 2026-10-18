import Foundation

enum QuoteQuality: String, Codable, Sendable {
    case live
    case delayed
    case simulated

    var title: String {
        switch self {
        case .live: "Live"
        case .delayed: "Verzögert"
        case .simulated: "Simuliert"
        }
    }
}

struct Quote: Equatable, Sendable {
    let instrumentID: InstrumentID
    var bid: Decimal
    var ask: Decimal
    var last: Decimal
    var previousClose: Decimal
    var dayHigh: Decimal
    var dayLow: Decimal
    var volume24h: Decimal?
    var liquidityUSD: Decimal?
    var timestamp: Date
    var source: ProviderID
    var quality: QuoteQuality
    var isSyntheticSpread: Bool

    var mid: Decimal {
        (bid + ask) / 2
    }

    var spread: Decimal {
        ask - bid
    }

    var spreadFraction: Decimal {
        mid > 0 ? spread / mid : 0
    }

    var change: Decimal {
        last - previousClose
    }

    var changeFraction: Decimal {
        previousClose > 0 ? change / previousClose : 0
    }

    func age(at now: Date) -> TimeInterval {
        now.timeIntervalSince(timestamp)
    }
}
