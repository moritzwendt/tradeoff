import Foundation
import SwiftData

@MainActor
enum LedgerWriter {
    @discardableResult
    static func record(
        preview: ExecutionPreview,
        instrument: Instrument,
        account: AccountRecord,
        existing: PositionRecord?,
        context: ModelContext,
        at time: Date
    ) -> FillRecord {
        let outcome = PositionMath.apply(
            side: preview.side,
            quantity: preview.quantity,
            gross: preview.gross,
            fee: preview.fee,
            to: existing?.state ?? PositionState()
        )

        switch preview.side {
        case .buy: account.cash -= preview.total
        case .sell: account.cash += preview.total
        }
        account.totalFees += preview.fee
        account.realizedPnL += outcome.realizedDelta

        if let existing {
            if outcome.state.quantity == 0 {
                context.delete(existing)
            } else {
                existing.apply(outcome.state, at: time)
            }
        } else {
            context.insert(PositionRecord(instrument: instrument, state: outcome.state, at: time))
        }

        let fill = FillRecord(
            instrument: instrument,
            side: preview.side,
            preview: preview,
            realizedPnL: outcome.realizedDelta,
            cashAfter: account.cash,
            timestamp: time
        )
        context.insert(fill)
        return fill
    }
}
