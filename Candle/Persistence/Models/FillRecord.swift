import Foundation
import SwiftData

@Model
final class FillRecord {
    var id: UUID
    var instrumentID: String
    var instrument: Instrument
    var sideRaw: String
    var quantity: Decimal
    var executionPrice: Decimal
    var referencePrice: Decimal
    var slippageCost: Decimal
    var gross: Decimal
    var fee: Decimal
    var total: Decimal
    var realizedPnL: Decimal
    var cashAfter: Decimal
    var spreadFraction: Decimal
    var qualityRaw: String
    var isSyntheticSpread: Bool
    var timestamp: Date

    init(
        instrument: Instrument,
        side: OrderSide,
        preview: ExecutionPreview,
        realizedPnL: Decimal,
        cashAfter: Decimal,
        timestamp: Date
    ) {
        id = UUID()
        instrumentID = instrument.id
        self.instrument = instrument
        sideRaw = side.rawValue
        quantity = preview.quantity
        executionPrice = preview.executionPrice
        referencePrice = preview.referencePrice
        slippageCost = preview.slippageCost
        gross = preview.gross
        fee = preview.fee
        total = preview.total
        self.realizedPnL = realizedPnL
        self.cashAfter = cashAfter
        spreadFraction = preview.spreadFraction
        qualityRaw = preview.quality.rawValue
        isSyntheticSpread = preview.isSyntheticSpread
        self.timestamp = timestamp
    }

    var side: OrderSide {
        OrderSide(rawValue: sideRaw) ?? .buy
    }

    var quality: QuoteQuality {
        QuoteQuality(rawValue: qualityRaw) ?? .simulated
    }
}
