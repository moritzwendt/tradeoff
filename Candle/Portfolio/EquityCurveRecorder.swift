import Foundation
import SwiftData

@MainActor
final class EquityCurveRecorder {
    private let context: ModelContext
    private let hub: QuoteHub
    private let clock: () -> Date
    private let minimumInterval: TimeInterval
    private var lastRecorded: Date?

    init(
        context: ModelContext,
        hub: QuoteHub,
        minimumInterval: TimeInterval = 300,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.context = context
        self.hub = hub
        self.minimumInterval = minimumInterval
        self.clock = clock
    }

    func record(force: Bool = false) {
        let now = clock()
        if !force, let last = lastRecorded, now.timeIntervalSince(last) < minimumInterval {
            return
        }
        guard let account = (try? context.fetch(FetchDescriptor<AccountRecord>()))?.first else { return }
        let positions = (try? context.fetch(FetchDescriptor<PositionRecord>())) ?? []
        let valuation = PortfolioValuator.value(
            account: account.snapshot,
            holdings: positions.map(\.holding),
            quotes: hub.quotes
        )
        context.insert(EquitySnapshotRecord(time: now, equity: valuation.equity, cash: valuation.cash))
        try? context.save()
        lastRecorded = now
    }
}
