import Foundation

enum QuotePoller {
    static func run(
        interval: TimeInterval,
        backoff: Backoff,
        continuation: AsyncStream<ProviderEvent>.Continuation,
        fetch: @Sendable () async throws -> [Quote]
    ) async {
        var wait = interval
        var attempt = 0
        var isFailing = false

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(wait))
            } catch {
                return
            }
            do {
                let quotes = try await fetch()
                if isFailing {
                    continuation.yield(.status(.live))
                    isFailing = false
                    attempt = 0
                }
                for quote in quotes {
                    continuation.yield(.quote(quote))
                }
                wait = interval
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
