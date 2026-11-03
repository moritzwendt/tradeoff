import Foundation

actor FinnhubProvider: PriceProvider {
    nonisolated static let restBaseURL = "https://finnhub.io/api/v1"
    nonisolated static let keyHeader = "X-Finnhub-Token"
    nonisolated static let requestsPerMinute = 55
    nonisolated static let minimumPollInterval: TimeInterval = 10
    nonisolated static let secondsPerSymbol: TimeInterval = 1.5
    nonisolated static let historyCacheLifetime: TimeInterval = 120
    nonisolated static let minimumSearchLength = 1

    nonisolated let id: ProviderID = .finnhub
    nonisolated let apiKey: String?

    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: true,
        hasLiquidity: false,
        isDelayed: false,
        requiresAPIKey: true,
        supportedAssetClasses: [.stock, .etf],
        pollInterval: nil
    )

    nonisolated var availability: ProviderAvailability {
        apiKey == nil ? .missingAPIKey : .ready
    }

    private struct HistoryKey: Hashable {
        let symbol: String
        let range: ChartRange
    }

    private let http: HTTPClient
    private let clock: @Sendable () -> Date
    private let backoff = Backoff(base: 2, factor: 2, maximum: 60)
    private var historyCache: [HistoryKey: (loadedAt: Date, candles: [Candlestick])] = [:]

    init(
        apiKey: String?,
        transport: any HTTPTransport = URLSessionTransport(),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.apiKey = apiKey
        http = HTTPClient(
            provider: .finnhub,
            transport: transport,
            limiter: RateLimiter(capacity: Self.requestsPerMinute, per: 60),
            headers: [
                Self.keyHeader: apiKey ?? "",
                "Accept": "application/json"
            ]
        )
        self.clock = clock
    }

    nonisolated static func pollInterval(forSymbols count: Int) -> TimeInterval {
        max(minimumPollInterval, Double(count) * secondsPerSymbol)
    }

    func catalog() -> [Instrument] {
        FinnhubCatalog.featuredInstruments
    }

    func search(query: String) async throws -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumSearchLength else { return catalog() }
        try requireKey()
        let data = try await http.get(
            Self.restBaseURL,
            path: "/search",
            query: [URLQueryItem(name: "q", value: trimmed)]
        )
        return try FinnhubParsing.searchResults(data)
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        let targets = instruments.filter { $0.provider == .finnhub }
        guard !targets.isEmpty else { return [] }
        try requireKey()
        let now = clock()
        let http = http

        let results = await withTaskGroup(of: (Int, Result<Quote?, Error>).self) { group in
            for (index, instrument) in targets.enumerated() {
                group.addTask {
                    do {
                        let data = try await http.get(
                            Self.restBaseURL,
                            path: "/quote",
                            query: [URLQueryItem(name: "symbol", value: instrument.providerSymbol)]
                        )
                        let quote = try FinnhubParsing.quote(data).quote(instrumentID: instrument.id, at: now)
                        return (index, .success(quote))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            var collected: [(Int, Result<Quote?, Error>)] = []
            for await result in group {
                collected.append(result)
            }
            return collected.sorted { $0.0 < $1.0 }
        }

        if Task.isCancelled { throw CancellationError() }

        var quotes: [Quote] = []
        var firstError: Error?
        for (_, result) in results {
            switch result {
            case .success(let quote):
                if let quote { quotes.append(quote) }
            case .failure(let error):
                if error is CancellationError { throw error }
                firstError = firstError ?? error
            }
        }
        if quotes.isEmpty, let firstError {
            throw firstError
        }
        return quotes
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        let targets = instruments.filter { $0.provider == .finnhub }
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self, bufferingPolicy: .bufferingNewest(256))
        let task = Task { [weak self] in
            guard let self, !targets.isEmpty else {
                continuation.finish()
                return
            }
            await QuotePoller.run(
                interval: Self.pollInterval(forSymbols: targets.count),
                backoff: self.backoff,
                continuation: continuation
            ) {
                try await self.snapshot(for: targets)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        guard instrument.provider == .finnhub else {
            throw ProviderError.unknownInstrument(instrument.id)
        }
        try requireKey()
        let key = HistoryKey(symbol: instrument.providerSymbol, range: range)
        let now = clock()
        if let cached = historyCache[key], now.timeIntervalSince(cached.loadedAt) < Self.historyCacheLifetime {
            return cached.candles
        }

        let request = FinnhubParsing.candleRequest(for: range)
        let data: Data
        do {
            data = try await http.get(
                Self.restBaseURL,
                path: "/stock/candle",
                query: [
                    URLQueryItem(name: "symbol", value: instrument.providerSymbol),
                    URLQueryItem(name: "resolution", value: request.resolution),
                    URLQueryItem(name: "from", value: String(Int(now.addingTimeInterval(-request.lookback).timeIntervalSince1970))),
                    URLQueryItem(name: "to", value: String(Int(now.timeIntervalSince1970)))
                ]
            )
        } catch ProviderError.accessDenied {
            throw ProviderError.historyUnavailable(instrument.id)
        }

        var candles = try FinnhubParsing.candles(data)
        if range == .day {
            candles = FinnhubParsing.latestSession(in: candles)
        }
        guard !candles.isEmpty else {
            throw ProviderError.historyUnavailable(instrument.id)
        }
        historyCache[key] = (now, candles)
        return candles
    }

    private func requireKey() throws {
        guard apiKey != nil else {
            throw ProviderError.missingAPIKey(.finnhub)
        }
    }
}
