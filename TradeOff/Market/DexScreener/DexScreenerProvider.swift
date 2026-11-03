import Foundation

actor DexScreenerProvider: PriceProvider {
    nonisolated static let restBaseURL = "https://api.dexscreener.com"
    nonisolated static let geckoBaseURL = "https://api.geckoterminal.com/api/v2"
    nonisolated static let maxAddressesPerRequest = 30
    nonisolated static let pollInterval: TimeInterval = 5
    nonisolated static let historyCacheLifetime: TimeInterval = 120
    nonisolated static let minimumSearchLength = 2

    nonisolated let id: ProviderID = .dexScreener

    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: true,
        hasLiquidity: true,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: [.memeCoin],
        pollInterval: DexScreenerProvider.pollInterval
    )

    nonisolated var availability: ProviderAvailability { .ready }

    private struct Pool: Sendable {
        let chain: String
        let pairAddress: String
    }

    private struct HistoryKey: Hashable {
        let id: InstrumentID
        let range: ChartRange
    }

    private let dex: HTTPClient
    private let gecko: HTTPClient
    private let clock: @Sendable () -> Date
    private let backoff = Backoff(base: 2, factor: 2, maximum: 30)
    private var pools: [InstrumentID: Pool] = [:]
    private var historyCache: [HistoryKey: (loadedAt: Date, candles: [Candlestick])] = [:]

    init(
        dex: HTTPClient = HTTPClient(
            provider: .dexScreener,
            limiter: RateLimiter(capacity: 250, per: 60)
        ),
        gecko: HTTPClient = HTTPClient(
            provider: .dexScreener,
            limiter: RateLimiter(capacity: 28, per: 60),
            headers: ["Accept": "application/json;version=20230302"]
        ),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.dex = dex
        self.gecko = gecko
        self.clock = clock
    }

    func catalog() -> [Instrument] {
        DexScreenerCatalog.featuredInstruments
    }

    func search(query: String) async throws -> [Instrument] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumSearchLength else { return catalog() }
        let data = try await dex.get(
            Self.restBaseURL,
            path: "/latest/dex/search",
            query: [URLQueryItem(name: "q", value: trimmed)]
        )
        return DexParsing.searchResults(from: try DexParsing.pairs(fromSearch: data))
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        let targets = instruments.filter { $0.provider == .dexScreener }
        let refs = targets.compactMap { instrument in
            DexTokenRef(providerSymbol: instrument.providerSymbol).map { (instrument, $0) }
        }
        guard !refs.isEmpty else { return [] }

        let now = clock()
        var quotes: [Quote] = []
        var firstError: Error?

        let byChain = Dictionary(grouping: refs, by: { $0.1.chain.lowercased() })
        for chain in byChain.keys.sorted() {
            let group = byChain[chain] ?? []
            for start in stride(from: 0, to: group.count, by: Self.maxAddressesPerRequest) {
                let chunk = Array(group[start..<min(start + Self.maxAddressesPerRequest, group.count)])
                do {
                    let pairs = try await fetchPairs(chain: group[0].1.chain, addresses: chunk.map { $0.1.address })
                    for (instrument, ref) in chunk {
                        guard let pair = DexParsing.bestPair(for: ref, in: pairs),
                              let quote = DexParsing.quote(from: pair, instrumentID: instrument.id, at: now)
                        else { continue }
                        pools[instrument.id] = Pool(chain: pair.chainId, pairAddress: pair.pairAddress)
                        quotes.append(quote)
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    firstError = firstError ?? error
                }
            }
        }

        if quotes.isEmpty, let firstError {
            throw firstError
        }
        return quotes
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        let targets = instruments.filter { $0.provider == .dexScreener }
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self, bufferingPolicy: .bufferingNewest(256))
        let task = Task { [weak self] in
            await self?.poll(targets, continuation: continuation)
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        guard instrument.provider == .dexScreener else {
            throw ProviderError.unknownInstrument(instrument.id)
        }
        let key = HistoryKey(id: instrument.id, range: range)
        let now = clock()
        if let cached = historyCache[key], now.timeIntervalSince(cached.loadedAt) < Self.historyCacheLifetime {
            return cached.candles
        }

        if pools[instrument.id] == nil {
            _ = try await snapshot(for: [instrument])
        }
        guard
            let pool = pools[instrument.id],
            let network = DexScreenerCatalog.geckoNetworks[pool.chain.lowercased()]
        else {
            throw ProviderError.historyUnavailable(instrument.id)
        }

        let request = GeckoTerminalOHLCV.request(for: range)
        let data = try await gecko.get(
            Self.geckoBaseURL,
            path: "/networks/\(network)/pools/\(pool.pairAddress)/ohlcv/\(request.timeframe)",
            query: [
                URLQueryItem(name: "aggregate", value: String(request.aggregate)),
                URLQueryItem(name: "limit", value: String(request.limit)),
                URLQueryItem(name: "currency", value: "usd"),
                URLQueryItem(name: "token", value: "base")
            ]
        )
        let candles = try GeckoTerminalOHLCV.parse(data)
        guard !candles.isEmpty else {
            throw ProviderError.historyUnavailable(instrument.id)
        }
        historyCache[key] = (now, candles)
        return candles
    }

    private func fetchPairs(chain: String, addresses: [String]) async throws -> [DexPair] {
        let data = try await dex.get(
            Self.restBaseURL,
            path: "/tokens/v1/\(chain)/\(addresses.joined(separator: ","))"
        )
        return try DexParsing.pairs(fromTokens: data)
    }

    private func poll(_ instruments: [Instrument], continuation: AsyncStream<ProviderEvent>.Continuation) async {
        guard !instruments.isEmpty else { return }
        var wait = Self.pollInterval
        var attempt = 0
        var isFailing = false

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(wait))
            } catch {
                return
            }
            do {
                let quotes = try await snapshot(for: instruments)
                if isFailing {
                    continuation.yield(.status(.live))
                    isFailing = false
                    attempt = 0
                }
                for quote in quotes {
                    continuation.yield(.quote(quote))
                }
                wait = Self.pollInterval
            } catch is CancellationError {
                return
            } catch {
                isFailing = true
                continuation.yield(.status(attempt >= 2 ? .failed(error.localizedDescription) : .reconnecting))
                wait = QuoteHub.retryDelay(for: error, attempt: attempt, backoff: backoff)
                attempt += 1
            }
        }
    }
}
