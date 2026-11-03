import Foundation

actor AlpacaProvider: PriceProvider {
    nonisolated static let dataBaseURL = "https://data.alpaca.markets"
    nonisolated static let keyIDHeader = "APCA-API-KEY-ID"
    nonisolated static let secretHeader = "APCA-API-SECRET-KEY"
    nonisolated static let requestsPerMinute = 180
    nonisolated static let historyCacheLifetime: TimeInterval = 120

    nonisolated let id: ProviderID = .alpaca
    nonisolated let keyID: String?
    nonisolated let secretKey: String?

    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: true,
        hasLiquidity: false,
        isDelayed: true,
        requiresAPIKey: true,
        supportedAssetClasses: [.stock, .etf],
        pollInterval: nil,
        providesQuotes: false
    )

    nonisolated var availability: ProviderAvailability {
        keyID == nil || secretKey == nil ? .missingAPIKey : .ready
    }

    private struct HistoryKey: Hashable {
        let symbol: String
        let range: ChartRange
    }

    private let http: HTTPClient
    private let clock: @Sendable () -> Date
    private var historyCache: [HistoryKey: (loadedAt: Date, candles: [Candlestick])] = [:]

    init(
        keyID: String?,
        secretKey: String?,
        transport: any HTTPTransport = URLSessionTransport(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keyID = keyID
        self.secretKey = secretKey
        http = HTTPClient(
            provider: .alpaca,
            transport: transport,
            limiter: RateLimiter(capacity: Self.requestsPerMinute, per: 60),
            headers: [
                Self.keyIDHeader: keyID ?? "",
                Self.secretHeader: secretKey ?? "",
                "Accept": "application/json"
            ]
        )
        self.clock = clock
    }

    func catalog() -> [Instrument] {
        []
    }

    func search(query: String) async throws -> [Instrument] {
        []
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        []
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        AsyncStream { $0.finish() }
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        guard instrument.assetClass == .stock || instrument.assetClass == .etf else {
            throw ProviderError.historyUnavailable(instrument.id)
        }
        guard availability == .ready else {
            throw ProviderError.missingAPIKey(.alpaca)
        }
        let key = HistoryKey(symbol: instrument.symbol, range: range)
        let now = clock()
        if let cached = historyCache[key], now.timeIntervalSince(cached.loadedAt) < Self.historyCacheLifetime {
            return cached.candles
        }

        let request = AlpacaParsing.barsRequest(for: range)
        let end = now.addingTimeInterval(-AlpacaParsing.recentDataDelay)
        let start = end.addingTimeInterval(-request.lookback)

        let data: Data
        do {
            data = try await http.get(
                Self.dataBaseURL,
                path: "/v2/stocks/bars",
                query: [
                    URLQueryItem(name: "symbols", value: instrument.symbol),
                    URLQueryItem(name: "timeframe", value: request.timeframe),
                    URLQueryItem(name: "start", value: AlpacaParsing.timestamp(start)),
                    URLQueryItem(name: "end", value: AlpacaParsing.timestamp(end)),
                    URLQueryItem(name: "limit", value: String(AlpacaParsing.barLimit)),
                    URLQueryItem(name: "adjustment", value: "split"),
                    URLQueryItem(name: "feed", value: "sip"),
                    URLQueryItem(name: "sort", value: "asc")
                ]
            )
        } catch ProviderError.invalidResponse {
            throw ProviderError.historyUnavailable(instrument.id)
        }

        var candles = try AlpacaParsing.candles(data, symbol: instrument.symbol)
        if let bucket = request.intradayBucket {
            candles = CandleSessions.regularHours(in: candles, bucket: bucket)
        }
        if range == .day {
            candles = CandleSessions.latest(in: candles)
        }
        guard !candles.isEmpty else {
            throw ProviderError.historyUnavailable(instrument.id)
        }
        historyCache[key] = (now, candles)
        return candles
    }
}
