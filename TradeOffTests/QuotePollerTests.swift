import Foundation
import Testing
@testable import TradeOff

private actor Script {
    private var results: [Result<[Quote], Error>]
    private(set) var calls = 0

    init(_ results: [Result<[Quote], Error>]) {
        self.results = results
    }

    func next() throws -> [Quote] {
        calls += 1
        let result = results.count > 1 ? results.removeFirst() : results[0]
        return try result.get()
    }
}

struct QuotePollerTests {
    private let backoff = Backoff(base: 0.01, factor: 2, maximum: 0.02)
    private let quote = TestSupport.quote(for: TestSupport.instrument("AAPL", provider: .finnhub))

    private func collect(_ count: Int, script: Script) async -> [ProviderEvent] {
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self)
        let backoff = backoff
        let task = Task {
            await QuotePoller.run(interval: 0.01, backoff: backoff, continuation: continuation) {
                try await script.next()
            }
            continuation.finish()
        }
        var events: [ProviderEvent] = []
        for await event in stream {
            events.append(event)
            if events.count == count { break }
        }
        task.cancel()
        return events
    }

    @Test func yieldsQuotesFromEveryFetch() async {
        let script = Script([.success([quote])])
        let events = await collect(3, script: script)
        #expect(events == [.quote(quote), .quote(quote), .quote(quote)])
    }

    @Test func failuresEscalateFromReconnectingToFailed() async {
        let script = Script([.failure(ProviderError.network(.finnhub))])
        let events = await collect(3, script: script)
        #expect(events == [
            .status(.reconnecting),
            .status(.reconnecting),
            .status(.failed("Keine Verbindung zu Finnhub"))
        ])
    }

    @Test func recoveryReportsLiveBeforeQuotes() async {
        let script = Script([
            .failure(ProviderError.network(.finnhub)),
            .success([quote])
        ])
        let events = await collect(3, script: script)
        #expect(events == [.status(.reconnecting), .status(.live), .quote(quote)])
    }

    @Test func cancellationStopsPolling() async {
        let script = Script([.success([quote])])
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self)
        let backoff = backoff
        let task = Task {
            await QuotePoller.run(interval: 0.01, backoff: backoff, continuation: continuation) {
                try await script.next()
            }
            continuation.finish()
        }
        task.cancel()
        await task.value
        var count = 0
        for await _ in stream { count += 1 }
        #expect(count <= 1)
    }
}
