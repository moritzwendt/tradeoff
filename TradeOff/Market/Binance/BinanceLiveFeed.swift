import Foundation

struct BinanceQuoteBook: Sendable {
    private var quotes: [String: Quote]

    init(seed: [String: Quote]) {
        quotes = seed
    }

    mutating func apply(_ message: BinanceStreamMessage) {
        switch message {
        case .book(let symbol, let bid, let ask):
            guard var quote = quotes[symbol], bid > 0, ask >= bid else { return }
            quote.bid = bid
            quote.ask = ask
            quotes[symbol] = quote
        case .mini(let symbol, let last, let open, let high, let low, let quoteVolume):
            guard var quote = quotes[symbol], last > 0 else { return }
            quote.last = last
            if open > 0 { quote.previousClose = open }
            quote.dayHigh = high
            quote.dayLow = low
            if let quoteVolume { quote.volume24h = quoteVolume }
            quotes[symbol] = quote
        }
    }

    func quotes(at now: Date) -> [Quote] {
        quotes.values.map { quote in
            var copy = quote
            copy.timestamp = now
            return copy
        }
    }
}

actor BinanceLiveFeed {
    private var book: BinanceQuoteBook
    private var lastAlive: Date
    private(set) var receivedMessages = 0

    init(book: BinanceQuoteBook, now: Date) {
        self.book = book
        lastAlive = now
    }

    func ingest(_ data: Data, at now: Date) {
        lastAlive = now
        receivedMessages += 1
        if let message = BinanceStreamMessage.parse(data) {
            book.apply(message)
        }
    }

    func markAlive(at now: Date) {
        lastAlive = now
    }

    func drain(at now: Date, staleAfter: TimeInterval) -> [Quote]? {
        guard now.timeIntervalSince(lastAlive) <= staleAfter else { return nil }
        return book.quotes(at: now)
    }
}
