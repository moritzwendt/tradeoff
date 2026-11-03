import Foundation

enum BinanceStreamError: Error {
    case stale
    case rotation
}

actor BinanceProvider: PriceProvider {
    nonisolated static let streamBaseURL = "wss://stream.binance.com:9443/stream"
    nonisolated static let restBaseURL = "https://api.binance.com"
    nonisolated static let tickerChunkSize = 20
    nonisolated static let maxStreamSymbols = 500
    nonisolated static let historyCacheLifetime: TimeInterval = 60
    nonisolated static let connectionLifetime: TimeInterval = 23 * 3600
    nonisolated static let pingInterval: TimeInterval = 15
    nonisolated static let staleAfter: TimeInterval = 45

    nonisolated let id: ProviderID = .binance

    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: true,
        hasHistory: true,
        hasLiquidity: false,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: [.crypto],
        pollInterval: nil
    )

    nonisolated var availability: ProviderAvailability { .ready }

    private struct HistoryKey: Hashable {
        let symbol: String
        let range: ChartRange
    }

    private let http: HTTPClient
    private let session: URLSession
    private let clock: @Sendable () -> Date
    private let backoff = Backoff(base: 1, factor: 2, maximum: 30)
    private var listingsTask: Task<[BinanceListing], Error>?
    private var historyCache: [HistoryKey: (loadedAt: Date, candles: [Candlestick])] = [:]

    init(
        http: HTTPClient = HTTPClient(
            provider: .binance,
            limiter: RateLimiter(capacity: 3000, per: 60)
        ),
        session: URLSession = .shared,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = http
        self.session = session
        self.clock = clock
    }

    nonisolated static func streamURL(for symbols: [String]) -> URL? {
        let streams = symbols
            .prefix(maxStreamSymbols)
            .flatMap { ["\($0.lowercased())@bookTicker", "\($0.lowercased())@miniTicker"] }
            .joined(separator: "/")
        return URL(string: "\(streamBaseURL)?streams=\(streams)")
    }

    func catalog() -> [Instrument] {
        BinanceCatalog.featured.map(\.instrument)
    }

    func search(query: String) async throws -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return catalog() }
        let listings = try await loadListings()
        return BinanceCatalog.search(trimmed, in: listings).map(\.instrument)
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        let targets = instruments.filter { $0.provider == .binance }
        guard !targets.isEmpty else { return [] }
        let idBySymbol = Dictionary(targets.map { ($0.providerSymbol, $0.id) }, uniquingKeysWith: { first, _ in first })
        let symbols = Array(idBySymbol.keys).sorted()
        let now = clock()

        var quotes: [Quote] = []
        for start in stride(from: 0, to: symbols.count, by: Self.tickerChunkSize) {
            let chunk = Array(symbols[start..<min(start + Self.tickerChunkSize, symbols.count)])
            let tickers = try await tickers(for: chunk)
            for ticker in tickers {
                if let identifier = idBySymbol[ticker.symbol], let quote = ticker.quote(instrumentID: identifier, at: now) {
                    quotes.append(quote)
                }
            }
        }
        return quotes
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        let targets = instruments.filter { $0.provider == .binance }
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self, bufferingPolicy: .bufferingNewest(512))
        let task = Task { [weak self] in
            await self?.runStream(targets, continuation: continuation)
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        guard instrument.provider == .binance else {
            throw ProviderError.unknownInstrument(instrument.id)
        }
        let key = HistoryKey(symbol: instrument.providerSymbol, range: range)
        let now = clock()
        if let cached = historyCache[key], now.timeIntervalSince(cached.loadedAt) < Self.historyCacheLifetime {
            return cached.candles
        }
        let data = try await http.get(
            Self.restBaseURL,
            path: "/api/v3/klines",
            query: [
                URLQueryItem(name: "symbol", value: instrument.providerSymbol),
                URLQueryItem(name: "interval", value: BinanceKlines.interval(for: range.interval)),
                URLQueryItem(name: "limit", value: String(range.candleCount))
            ],
            cost: 2
        )
        let candles = try BinanceKlines.parse(data)
        guard !candles.isEmpty else {
            throw ProviderError.historyUnavailable(instrument.id)
        }
        historyCache[key] = (now, candles)
        return candles
    }

    private func loadListings() async throws -> [BinanceListing] {
        if let listingsTask {
            return try await listingsTask.value
        }
        let http = http
        let task = Task<[BinanceListing], Error> {
            let data = try await http.get(
                Self.restBaseURL,
                path: "/api/v3/exchangeInfo",
                query: [
                    URLQueryItem(name: "permissions", value: "SPOT"),
                    URLQueryItem(name: "symbolStatus", value: "TRADING"),
                    URLQueryItem(name: "showPermissionSets", value: "false")
                ],
                cost: 20,
                timeout: 30
            )
            return try JSONDecoder().decode(BinanceExchangeInfo.self, from: data).listings
        }
        listingsTask = task
        do {
            return try await task.value
        } catch {
            listingsTask = nil
            throw error
        }
    }

    private func tickers(for symbols: [String]) async throws -> [BinanceTicker24h] {
        do {
            return try await fetchTickers(symbols)
        } catch ProviderError.invalidResponse where symbols.count > 1 {
            var result: [BinanceTicker24h] = []
            for symbol in symbols {
                if let tickers = try? await fetchTickers([symbol]) {
                    result += tickers
                }
            }
            return result
        }
    }

    private func fetchTickers(_ symbols: [String]) async throws -> [BinanceTicker24h] {
        let encoded = "[" + symbols.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        let data = try await http.get(
            Self.restBaseURL,
            path: "/api/v3/ticker/24hr",
            query: [URLQueryItem(name: "symbols", value: encoded)],
            cost: 2
        )
        do {
            return try JSONDecoder().decode([BinanceTicker24h].self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.binance)
        }
    }

    private func runStream(_ instruments: [Instrument], continuation: AsyncStream<ProviderEvent>.Continuation) async {
        guard !instruments.isEmpty else { return }
        let symbols = Array(Set(instruments.map(\.providerSymbol))).sorted()
        var attempt = 0

        while !Task.isCancelled {
            var feed: BinanceLiveFeed?
            do {
                let seed = try await snapshot(for: instruments)
                let idToSymbol = Dictionary(instruments.map { ($0.id, $0.providerSymbol) }, uniquingKeysWith: { first, _ in first })
                let book = BinanceQuoteBook(
                    seed: Dictionary(
                        seed.compactMap { quote in idToSymbol[quote.instrumentID].map { ($0, quote) } },
                        uniquingKeysWith: { first, _ in first }
                    )
                )
                let activeFeed = BinanceLiveFeed(book: book, now: clock())
                feed = activeFeed
                continuation.yield(.status(.live))
                try await pump(feed: activeFeed, symbols: symbols, continuation: continuation)
            } catch is CancellationError {
                return
            } catch BinanceStreamError.rotation {
                attempt = 0
                continue
            } catch {
                if Task.isCancelled { return }
                if let feed, await feed.receivedMessages > 0 {
                    attempt = 0
                }
                let status: ProviderStatus = attempt >= 2
                    ? .failed(error.localizedDescription)
                    : .reconnecting
                continuation.yield(.status(status))
                let wait = QuoteHub.retryDelay(for: error, attempt: attempt, backoff: backoff)
                do {
                    try await Task.sleep(for: .seconds(wait))
                } catch {
                    return
                }
                attempt += 1
            }
        }
    }

    private func pump(
        feed: BinanceLiveFeed,
        symbols: [String],
        continuation: AsyncStream<ProviderEvent>.Continuation
    ) async throws {
        guard let url = Self.streamURL(for: symbols) else {
            throw ProviderError.invalidResponse(.binance)
        }
        let socket = session.webSocketTask(with: url)
        let clock = clock
        socket.resume()

        try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    while true {
                        let message = try await socket.receive()
                        switch message {
                        case .data(let data): await feed.ingest(data, at: clock())
                        case .string(let text): await feed.ingest(Data(text.utf8), at: clock())
                        @unknown default: break
                        }
                    }
                }
                group.addTask {
                    while true {
                        try await Task.sleep(for: .seconds(Self.pingInterval))
                        try await Self.ping(socket)
                        await feed.markAlive(at: clock())
                    }
                }
                group.addTask {
                    while true {
                        try await Task.sleep(for: .seconds(1))
                        guard let quotes = await feed.drain(at: clock(), staleAfter: Self.staleAfter) else {
                            throw BinanceStreamError.stale
                        }
                        for quote in quotes {
                            continuation.yield(.quote(quote))
                        }
                    }
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(Self.connectionLifetime))
                    throw BinanceStreamError.rotation
                }

                do {
                    try await group.next()
                } catch {
                    socket.cancel(with: .goingAway, reason: nil)
                    group.cancelAll()
                    throw error
                }
                socket.cancel(with: .goingAway, reason: nil)
                group.cancelAll()
            }
        } onCancel: {
            socket.cancel(with: .goingAway, reason: nil)
        }
    }

    private static func ping(_ socket: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            socket.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
