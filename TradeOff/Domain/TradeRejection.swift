import Foundation

enum TradeRejection: Error, Equatable, Sendable {
    case noQuote
    case staleQuote(age: TimeInterval)
    case marketClosed(MarketSession)
    case invalidQuantity
    case belowMinimum(Decimal)
    case insufficientFunds(required: Decimal, available: Decimal)
    case insufficientPosition(held: Decimal)
    case noLiquidityData

    var message: String {
        switch self {
        case .noQuote: "Kein Kurs verfügbar"
        case .staleQuote: "Kurs ist zu alt"
        case .marketClosed(let session): Self.closedMessage(session)
        case .invalidQuantity: "Menge eingeben"
        case .belowMinimum: "Order zu klein"
        case .insufficientFunds: "Nicht genug Guthaben"
        case .insufficientPosition: "Nicht genug Bestand"
        case .noLiquidityData: "Keine Liquiditätsdaten"
        }
    }

    private static func closedMessage(_ session: MarketSession) -> String {
        guard case .closed(let opensAt?) = session else { return "Markt geschlossen" }
        return "Markt geschlossen, öffnet \(TimeFormat.opening(opensAt))"
    }

    var blocksPreview: Bool {
        switch self {
        case .noQuote, .invalidQuantity, .noLiquidityData: true
        default: false
        }
    }
}
