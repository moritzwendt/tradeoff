import Foundation

enum CandleInterval: Sendable, Hashable {
    case minutes5
    case minutes30
    case hours4
    case day
    case week

    var seconds: TimeInterval {
        switch self {
        case .minutes5: 300
        case .minutes30: 1_800
        case .hours4: 14_400
        case .day: 86_400
        case .week: 604_800
        }
    }
}

enum ChartRange: String, CaseIterable, Identifiable, Sendable, Hashable {
    case day
    case week
    case month
    case quarter
    case year
    case max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "1T"
        case .week: "1W"
        case .month: "1M"
        case .quarter: "3M"
        case .year: "1J"
        case .max: "Max"
        }
    }

    var interval: CandleInterval {
        switch self {
        case .day: .minutes5
        case .week: .minutes30
        case .month: .hours4
        case .quarter, .year: .day
        case .max: .week
        }
    }

    var candleCount: Int {
        switch self {
        case .day: 288
        case .week: 336
        case .month: 180
        case .quarter: 90
        case .year: 365
        case .max: 260
        }
    }

    var duration: TimeInterval {
        interval.seconds * Double(candleCount)
    }
}
