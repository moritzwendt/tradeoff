import Foundation
import Testing
@testable import TradeOff

struct BackoffTests {
    @Test func delayDoublesUntilMaximum() {
        let backoff = Backoff(base: 2, factor: 2, maximum: 30)
        #expect(backoff.delay(attempt: 0) == 2)
        #expect(backoff.delay(attempt: 1) == 4)
        #expect(backoff.delay(attempt: 3) == 16)
        #expect(backoff.delay(attempt: 4) == 30)
        #expect(backoff.delay(attempt: 20) == 30)
    }

    @Test func negativeAttemptsUseBase() {
        #expect(Backoff().delay(attempt: -3) == 1)
    }
}

struct SlidingWindowTests {
    @Test func allowsRequestsUpToCapacityWithoutWaiting() {
        var window = SlidingWindow(capacity: 3, interval: 10)
        for _ in 0..<3 {
            #expect(window.reserve(at: FixedClock.epoch) == 0)
        }
    }

    @Test func waitsUntilOldestRequestLeavesWindow() {
        var window = SlidingWindow(capacity: 2, interval: 10)
        _ = window.reserve(at: FixedClock.epoch)
        _ = window.reserve(at: FixedClock.epoch.addingTimeInterval(4))
        let wait = window.reserve(at: FixedClock.epoch.addingTimeInterval(5))
        #expect(wait == 5)
    }

    @Test func expiredRequestsFreeCapacity() {
        var window = SlidingWindow(capacity: 1, interval: 10)
        _ = window.reserve(at: FixedClock.epoch)
        #expect(window.reserve(at: FixedClock.epoch.addingTimeInterval(10)) == 0)
    }

    @Test func weightedCostsConsumeMoreCapacity() {
        var window = SlidingWindow(capacity: 10, interval: 60)
        _ = window.reserve(cost: 8, at: FixedClock.epoch)
        #expect(window.reserve(cost: 1, at: FixedClock.epoch) == 0)
        #expect(window.reserve(cost: 2, at: FixedClock.epoch.addingTimeInterval(1)) == 59)
    }

    @Test func queuedRequestsAreSpacedOut() {
        var window = SlidingWindow(capacity: 1, interval: 2)
        #expect(window.reserve(at: FixedClock.epoch) == 0)
        #expect(window.reserve(at: FixedClock.epoch) == 2)
        #expect(window.reserve(at: FixedClock.epoch) == 4)
    }
}

struct RateLimiterTests {
    @Test func penaltyBlocksFurtherRequests() async {
        let limiter = RateLimiter(capacity: 100, per: 60, clock: { FixedClock.epoch })
        #expect(await limiter.reserve() == 0)
        await limiter.penalize(for: 12)
        #expect(await limiter.reserve() == 12)
    }

    @Test func shorterPenaltyDoesNotShortenLongerOne() async {
        let limiter = RateLimiter(capacity: 100, per: 60, clock: { FixedClock.epoch })
        await limiter.penalize(for: 20)
        await limiter.penalize(for: 5)
        #expect(await limiter.reserve() == 20)
    }
}

struct HTTPClientTests {
    private func client(_ transport: StubTransport, limiter: RateLimiter? = nil) -> HTTPClient {
        HTTPClient(provider: .binance, transport: transport, limiter: limiter, headers: ["Accept": "application/json"])
    }

    @Test func buildsURLWithQueryItems() async throws {
        let transport = StubTransport(body: "{}")
        _ = try await client(transport).get(
            "https://example.test",
            path: "/v1/items",
            query: [URLQueryItem(name: "symbol", value: "BTCUSDT"), URLQueryItem(name: "limit", value: "5")]
        )
        let url = try #require(transport.log.urls.first)
        #expect(url.absoluteString == "https://example.test/v1/items?symbol=BTCUSDT&limit=5")
    }

    @Test func returnsBodyOnSuccess() async throws {
        let data = try await client(StubTransport(body: "hello")).get("https://example.test", path: "/")
        #expect(String(decoding: data, as: UTF8.self) == "hello")
    }

    @Test func mapsTooManyRequestsAndPenalizesLimiter() async throws {
        let transport = StubTransport { _ in StubResponse(status: 429, headers: ["Retry-After": "7"]) }
        let limiter = RateLimiter(capacity: 100, per: 60, clock: { FixedClock.epoch })
        await #expect(throws: ProviderError.rateLimited(.binance, retryAfter: 7)) {
            _ = try await client(transport, limiter: limiter).get("https://example.test", path: "/")
        }
        #expect(await limiter.reserve() == 7)
    }

    @Test func usesDefaultPenaltyWithoutRetryAfterHeader() async throws {
        let transport = StubTransport(body: "", status: 418)
        let limiter = RateLimiter(capacity: 100, per: 60, clock: { FixedClock.epoch })
        await #expect(throws: ProviderError.rateLimited(.binance, retryAfter: nil)) {
            _ = try await client(transport, limiter: limiter).get("https://example.test", path: "/")
        }
        #expect(await limiter.reserve() == HTTPClient.defaultPenalty)
    }

    @Test func mapsRejectedCredentialsToAccessDenied() async {
        for status in [401, 403] {
            await #expect(throws: ProviderError.accessDenied(.binance)) {
                _ = try await client(StubTransport(body: "", status: status)).get("https://example.test", path: "/")
            }
        }
    }

    @Test func mapsServerErrorsToInvalidResponse() async {
        await #expect(throws: ProviderError.invalidResponse(.binance)) {
            _ = try await client(StubTransport(body: "", status: 500)).get("https://example.test", path: "/")
        }
    }

    @Test func mapsTransportFailuresToNetworkError() async {
        let transport = StubTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: ProviderError.network(.binance)) {
            _ = try await client(transport).get("https://example.test", path: "/")
        }
    }

    @Test func cancellationIsNotReportedAsNetworkError() async {
        let transport = StubTransport { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            _ = try await client(transport).get("https://example.test", path: "/")
        }
    }
}
