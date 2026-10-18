import Foundation
import Observation

@MainActor
@Observable
final class InstrumentDetailModel {
    let instrument: Instrument
    var range: ChartRange = .day
    var candles: [Candlestick] = []
    var selectedIndex: Int?
    var isLoading = true
    var loadFailed = false

    init(instrument: Instrument) {
        self.instrument = instrument
    }

    func load(using hub: QuoteHub) async {
        isLoading = candles.isEmpty
        selectedIndex = nil
        do {
            let loaded = try await hub.history(for: instrument, range: range)
            guard !Task.isCancelled else { return }
            candles = loaded
            loadFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            candles = []
            loadFailed = true
        }
        isLoading = false
    }

    func liveCandles(quote: Quote?) -> [Candlestick] {
        guard let quote, let last = candles.last else { return candles }
        var result = candles
        result[result.count - 1] = last.applying(price: quote.last)
        return result
    }

    func rangeChange(in candles: [Candlestick]) -> (value: Decimal, fraction: Decimal)? {
        guard let first = candles.first, let last = candles.last, first.open > 0 else { return nil }
        let change = last.close - first.open
        return (change, change / first.open)
    }
}
