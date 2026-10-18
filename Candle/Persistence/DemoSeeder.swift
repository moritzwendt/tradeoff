import Foundation
import SwiftData

@MainActor
enum DemoSeeder {
    private struct Step {
        let daysAgo: Int
        let symbol: String
        let side: OrderSide
        let amount: Decimal?
        let fraction: Decimal?
    }

    private static let plan: [Step] = [
        Step(daysAgo: 75, symbol: "AAPL", side: .buy, amount: 2_500, fraction: nil),
        Step(daysAgo: 60, symbol: "BTC", side: .buy, amount: 2_000, fraction: nil),
        Step(daysAgo: 48, symbol: "NVDA", side: .buy, amount: 1_800, fraction: nil),
        Step(daysAgo: 33, symbol: "AAPL", side: .sell, amount: nil, fraction: Decimal(sign: .plus, exponent: -1, significand: 4)),
        Step(daysAgo: 25, symbol: "BONK", side: .buy, amount: 400, fraction: nil),
        Step(daysAgo: 18, symbol: "VOO", side: .buy, amount: 1_500, fraction: nil),
        Step(daysAgo: 11, symbol: "ETH", side: .buy, amount: 600, fraction: nil),
        Step(daysAgo: 6, symbol: "BONK", side: .sell, amount: nil, fraction: Decimal(sign: .plus, exponent: -1, significand: 5)),
        Step(daysAgo: 2, symbol: "TSLA", side: .buy, amount: 900, fraction: nil)
    ]

    static func seed(context: ModelContext, hub: QuoteHub, settings: AppSettings, now: Date = Date()) async {
        clear(context)
        let account = AccountRecord(startingBalance: settings.values.startingBalance, createdAt: now)
        context.insert(account)
        try? context.save()

        let catalog = await hub.catalog()
        let instruments = Dictionary(catalog.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
        await hub.refresh(catalog)

        var series: [InstrumentID: [Candlestick]] = [:]
        for step in plan {
            guard let instrument = instruments[step.symbol], series[instrument.id] == nil else { continue }
            if let candles = try? await hub.history(for: instrument, range: .quarter) {
                series[instrument.id] = candles
            }
        }

        let model = ExecutionModel(
            fees: settings.values.fees,
            maxQuoteAge: .infinity,
            minimumNotional: 1,
            ignoreMarketHours: true
        )

        var recorded: [FillRecord] = []
        for step in plan.sorted(by: { $0.daysAgo > $1.daysAgo }) {
            guard
                let instrument = instruments[step.symbol],
                let candles = series[instrument.id],
                candles.count > step.daysAgo
            else { continue }

            let candle = candles[candles.count - 1 - step.daysAgo]
            let time = candle.time.addingTimeInterval(14 * 3_600)
            let reference = hub.quote(for: instrument.id)
            let spread = reference?.spreadFraction ?? Decimal(sign: .plus, exponent: -4, significand: 4)
            let half = candle.close * spread / 2
            let quote = Quote(
                instrumentID: instrument.id,
                bid: (candle.close - half).marketRounded(),
                ask: (candle.close + half).marketRounded(),
                last: candle.close,
                previousClose: candle.open,
                dayHigh: candle.high,
                dayLow: candle.low,
                volume24h: nil,
                liquidityUSD: reference?.liquidityUSD,
                timestamp: time,
                source: .mock,
                quality: .simulated,
                isSyntheticSpread: true
            )

            let existing = position(for: instrument.id, in: context)
            let quantity: Decimal
            switch step.side {
            case .buy:
                quantity = ((step.amount ?? 0) / quote.ask).rounded(scale: instrument.assetClass.quantityScale, mode: .down)
            case .sell:
                quantity = ((existing?.quantity ?? 0) * (step.fraction ?? 0)).rounded(scale: instrument.assetClass.quantityScale, mode: .down)
            }

            let evaluation = model.evaluate(
                OrderRequest(instrumentID: instrument.id, side: step.side, quantity: quantity),
                instrument: instrument,
                quote: quote,
                cash: account.cash,
                heldQuantity: existing?.quantity ?? 0,
                now: time
            )
            guard evaluation.isExecutable, let preview = evaluation.preview else { continue }
            let fill = LedgerWriter.record(
                preview: preview,
                instrument: instrument,
                account: account,
                existing: existing,
                context: context,
                at: time
            )
            recorded.append(fill)
            try? context.save()
        }

        insertEquityHistory(
            fills: recorded,
            series: series,
            startingBalance: account.startingBalance,
            context: context,
            now: now
        )
        try? context.save()
    }

    private static func insertEquityHistory(
        fills: [FillRecord],
        series: [InstrumentID: [Candlestick]],
        startingBalance: Decimal,
        context: ModelContext,
        now: Date
    ) {
        guard let first = fills.map(\.timestamp).min(), let reference = series.values.first else { return }
        let sorted = fills.sorted { $0.timestamp < $1.timestamp }
        for (index, candle) in reference.enumerated() {
            let time = candle.time.addingTimeInterval(20 * 3_600)
            guard time >= first.addingTimeInterval(-86_400), time < now else { continue }
            var cash = startingBalance
            var quantities: [InstrumentID: Decimal] = [:]
            for fill in sorted where fill.timestamp <= time {
                switch fill.side {
                case .buy:
                    cash -= fill.total
                    quantities[fill.instrumentID, default: 0] += fill.quantity
                case .sell:
                    cash += fill.total
                    quantities[fill.instrumentID, default: 0] -= fill.quantity
                }
            }
            var holdings: Decimal = 0
            for (id, quantity) in quantities where quantity > 0 {
                if let close = series[id]?[safe: index]?.close {
                    holdings += quantity * close
                }
            }
            context.insert(EquitySnapshotRecord(time: time, equity: (cash + holdings).rounded(scale: 2), cash: cash))
        }
    }

    private static func position(for id: InstrumentID, in context: ModelContext) -> PositionRecord? {
        var descriptor = FetchDescriptor<PositionRecord>(predicate: #Predicate { $0.instrumentID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func clear(_ context: ModelContext) {
        deleteAll(FillRecord.self, in: context)
        deleteAll(PositionRecord.self, in: context)
        deleteAll(EquitySnapshotRecord.self, in: context)
        deleteAll(AccountRecord.self, in: context)
        try? context.save()
    }

    private static func deleteAll<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<Model>())) ?? [] {
            context.delete(item)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
