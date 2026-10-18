import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TradingService {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let hub: QuoteHub
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let clock: () -> Date

    init(context: ModelContext, hub: QuoteHub, settings: AppSettings, clock: @escaping () -> Date = { Date() }) {
        self.context = context
        self.hub = hub
        self.settings = settings
        self.clock = clock
    }

    func account() -> AccountRecord {
        if let existing = (try? context.fetch(FetchDescriptor<AccountRecord>()))?.first {
            return existing
        }
        let created = AccountRecord(startingBalance: settings.values.startingBalance)
        context.insert(created)
        try? context.save()
        return created
    }

    func position(for id: InstrumentID) -> PositionRecord? {
        var descriptor = FetchDescriptor<PositionRecord>(predicate: #Predicate { $0.instrumentID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func evaluate(_ request: OrderRequest, instrument: Instrument) -> ExecutionEvaluation {
        settings.executionModel.evaluate(
            request,
            instrument: instrument,
            quote: hub.quote(for: instrument.id),
            cash: account().cash,
            heldQuantity: position(for: instrument.id)?.quantity ?? 0,
            now: clock()
        )
    }

    @discardableResult
    func execute(_ request: OrderRequest, instrument: Instrument) throws -> FillRecord {
        let evaluation = evaluate(request, instrument: instrument)
        if let rejection = evaluation.rejection {
            throw rejection
        }
        guard let preview = evaluation.preview else {
            throw TradeRejection.noQuote
        }

        let fill = LedgerWriter.record(
            preview: preview,
            instrument: instrument,
            account: account(),
            existing: position(for: instrument.id),
            context: context,
            at: clock()
        )
        try context.save()
        return fill
    }

    func resetAccount() {
        deleteAll(FillRecord.self)
        deleteAll(PositionRecord.self)
        deleteAll(EquitySnapshotRecord.self)
        deleteAll(AccountRecord.self)
        context.insert(AccountRecord(startingBalance: settings.values.startingBalance))
        try? context.save()
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) {
        let items = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        for item in items {
            context.delete(item)
        }
    }
}
