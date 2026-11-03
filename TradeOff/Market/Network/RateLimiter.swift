import Foundation

struct SlidingWindow: Sendable {
    private struct Entry: Sendable {
        let time: Date
        let cost: Int
    }

    let capacity: Int
    let interval: TimeInterval
    private var entries: [Entry] = []

    init(capacity: Int, interval: TimeInterval) {
        self.capacity = capacity
        self.interval = interval
    }

    mutating func reserve(cost: Int = 1, at now: Date) -> TimeInterval {
        entries.removeAll { now.timeIntervalSince($0.time) >= interval }
        let cost = min(max(cost, 1), capacity)
        var used = entries.reduce(0) { $0 + $1.cost }
        var wait: TimeInterval = 0
        var index = 0
        while used + cost > capacity, index < entries.count {
            used -= entries[index].cost
            wait = max(wait, entries[index].time.addingTimeInterval(interval).timeIntervalSince(now))
            index += 1
        }
        entries.append(Entry(time: now.addingTimeInterval(wait), cost: cost))
        return wait
    }
}

actor RateLimiter {
    private var window: SlidingWindow
    private var blockedUntil: Date?
    private let clock: @Sendable () -> Date

    init(capacity: Int, per interval: TimeInterval, clock: @escaping @Sendable () -> Date = { Date() }) {
        window = SlidingWindow(capacity: capacity, interval: interval)
        self.clock = clock
    }

    func reserve(cost: Int = 1) -> TimeInterval {
        let now = clock()
        var wait = window.reserve(cost: cost, at: now)
        if let blockedUntil {
            wait = max(wait, blockedUntil.timeIntervalSince(now))
        }
        return max(wait, 0)
    }

    func acquire(cost: Int = 1) async throws {
        let wait = reserve(cost: cost)
        if wait > 0 {
            try await Task.sleep(for: .seconds(wait))
        }
    }

    func penalize(for seconds: TimeInterval) {
        let until = clock().addingTimeInterval(seconds)
        if let blockedUntil, blockedUntil > until { return }
        blockedUntil = until
    }
}
