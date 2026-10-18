import Foundation

actor MockPriceProvider: PriceProvider {
    struct Tuning: Equatable, Sendable {
        var tickInterval: Double
        var volatilityMultiplier: Double
    }

    nonisolated let id: ProviderID = .mock

    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: true,
        hasLiquidity: true,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: Set(AssetClass.allCases),
        pollInterval: nil
    )

    nonisolated var availability: ProviderAvailability { .ready }

    private struct State {
        let definition: MockInstrumentDefinition
        var mid: Decimal
        var dayHigh: Decimal
        var dayLow: Decimal
    }

    private let clock: @Sendable () -> Date
    private let order: [InstrumentID]
    private var states: [InstrumentID: State]
    private var generator: SplitMix64
    private(set) var tuning: Tuning

    init(definition: MockMarketDefinition, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
        tuning = Tuning(
            tickInterval: definition.tick.intervalSeconds,
            volatilityMultiplier: definition.tick.volatilityMultiplier
        )
        var states: [InstrumentID: State] = [:]
        var order: [InstrumentID] = []
        for item in definition.instruments {
            let identifier = item.instrument.id
            states[identifier] = State(
                definition: item,
                mid: item.startPrice,
                dayHigh: item.startPrice,
                dayLow: item.startPrice
            )
            order.append(identifier)
        }
        self.states = states
        self.order = order
        generator = SplitMix64(seed: 0xC4D1E)
    }

    static func bundled(clock: @escaping @Sendable () -> Date = { Date() }) throws -> MockPriceProvider {
        MockPriceProvider(definition: try MockMarketDefinition.load(), clock: clock)
    }

    func update(tuning: Tuning) {
        self.tuning = tuning
    }

    func catalog() -> [Instrument] {
        order.compactMap { states[$0]?.definition.instrument }
    }

    func search(query: String) -> [Instrument] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return catalog() }
        return catalog().filter {
            $0.symbol.lowercased().contains(needle) || $0.name.lowercased().contains(needle)
        }
    }

    func snapshot(for instruments: [Instrument]) -> [Quote] {
        instruments.compactMap { states[$0.id].map(makeQuote) }
    }

    func quotes(for instruments: [Instrument]) -> AsyncStream<Quote> {
        let ids = instruments.map(\.id)
        let (stream, continuation) = AsyncStream.makeStream(of: Quote.self, bufferingPolicy: .bufferingNewest(64))
        let task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let interval = await self.tuning.tickInterval
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                for quote in await self.advance(ids: ids) {
                    continuation.yield(quote)
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) throws -> [Candlestick] {
        guard let state = states[instrument.id] else {
            throw ProviderError.unknownInstrument(instrument.id)
        }
        return PriceSeriesGenerator.candles(
            for: state.definition,
            range: range,
            anchor: state.mid,
            now: clock()
        )
    }

    private func advance(ids: [InstrumentID]) -> [Quote] {
        var result: [Quote] = []
        for identifier in ids {
            guard var state = states[identifier] else { continue }
            let definition = state.definition
            let sigma = definition.dailyVolatility
                * (tuning.tickInterval / 86_400).squareRoot()
                * tuning.volatilityMultiplier
            let current = state.mid.doubleValue
            let anchor = definition.startPrice.doubleValue
            let pull = -0.0008 * log(current / anchor)
            let next = current * exp(sigma * generator.nextGaussian() + pull)
            state.mid = Decimal(next, scale: 12).roundedToSignificantDigits(8)
            state.dayHigh = max(state.dayHigh, state.mid)
            state.dayLow = min(state.dayLow, state.mid)
            states[identifier] = state
            result.append(makeQuote(state))
        }
        return result
    }

    private func makeQuote(_ state: State) -> Quote {
        let definition = state.definition
        let halfSpread = state.mid * Decimal(definition.spreadBps) / 20_000
        return Quote(
            instrumentID: definition.instrument.id,
            bid: (state.mid - halfSpread).marketRounded(),
            ask: (state.mid + halfSpread).marketRounded(),
            last: state.mid.marketRounded(),
            previousClose: definition.previousClose,
            dayHigh: state.dayHigh.marketRounded(),
            dayLow: state.dayLow.marketRounded(),
            volume24h: nil,
            liquidityUSD: definition.liquidityUSD,
            timestamp: clock(),
            source: .mock,
            quality: .simulated,
            isSyntheticSpread: true
        )
    }
}
