import Foundation
import SwiftData

@Model
final class PositionRecord {
    @Attribute(.unique) var instrumentID: String
    var instrument: Instrument
    var quantity: Decimal
    var averageCost: Decimal
    var realizedPnL: Decimal
    var openedAt: Date
    var updatedAt: Date

    init(instrument: Instrument, state: PositionState, at date: Date) {
        instrumentID = instrument.id
        self.instrument = instrument
        quantity = state.quantity
        averageCost = state.averageCost
        realizedPnL = state.realizedPnL
        openedAt = date
        updatedAt = date
    }

    var state: PositionState {
        PositionState(quantity: quantity, averageCost: averageCost, realizedPnL: realizedPnL)
    }

    var holding: HoldingSnapshot {
        HoldingSnapshot(instrument: instrument, quantity: quantity, averageCost: averageCost)
    }

    func apply(_ state: PositionState, at date: Date) {
        quantity = state.quantity
        averageCost = state.averageCost
        realizedPnL = state.realizedPnL
        updatedAt = date
    }
}
