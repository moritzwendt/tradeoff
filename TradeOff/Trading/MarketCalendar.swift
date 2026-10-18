import Foundation

enum MarketSession: Equatable, Sendable {
    case always
    case open(closesAt: Date)
    case closed(opensAt: Date?)

    var isOpen: Bool {
        switch self {
        case .always, .open: true
        case .closed: false
        }
    }
}

enum MarketCalendarKind: Sendable, Hashable {
    case alwaysOpen
    case usEquities
}

protocol MarketCalendar: Sendable {
    func session(at date: Date) -> MarketSession
}

struct AlwaysOpenCalendar: MarketCalendar {
    func session(at date: Date) -> MarketSession {
        .always
    }
}

struct USEquityCalendar: MarketCalendar {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        self.calendar = calendar
    }

    func session(at date: Date) -> MarketSession {
        let day = calendar.startOfDay(for: date)
        if isTradingDay(day), let open = sessionOpen(on: day), let close = sessionClose(on: day) {
            if date < open { return .closed(opensAt: open) }
            if date < close { return .open(closesAt: close) }
        }
        return .closed(opensAt: nextOpen(after: day))
    }

    func isTradingDay(_ day: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: day)
        guard weekday != 1, weekday != 7 else { return false }
        let year = calendar.component(.year, from: day)
        return !holidays(in: year).contains(calendar.startOfDay(for: day))
    }

    func holidays(in year: Int) -> Set<Date> {
        var days: [Date?] = [
            observedFixed(month: 1, day: 1, year: year, skipsSaturday: true),
            nthWeekday(ordinal: 3, weekday: 2, month: 1, year: year),
            nthWeekday(ordinal: 3, weekday: 2, month: 2, year: year),
            goodFriday(in: year),
            nthWeekday(ordinal: -1, weekday: 2, month: 5, year: year),
            observedFixed(month: 7, day: 4, year: year),
            nthWeekday(ordinal: 1, weekday: 2, month: 9, year: year),
            nthWeekday(ordinal: 4, weekday: 5, month: 11, year: year),
            observedFixed(month: 12, day: 25, year: year)
        ]
        if year >= 2022 {
            days.append(observedFixed(month: 6, day: 19, year: year))
        }
        return Set(days.compactMap { $0 }.map { calendar.startOfDay(for: $0) })
    }

    private func sessionOpen(on day: Date) -> Date? {
        calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day)
    }

    private func sessionClose(on day: Date) -> Date? {
        calendar.date(bySettingHour: 16, minute: 0, second: 0, of: day)
    }

    private func nextOpen(after day: Date) -> Date? {
        var cursor = day
        for _ in 0..<14 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
            if isTradingDay(cursor) { return sessionOpen(on: cursor) }
        }
        return nil
    }

    private func observedFixed(month: Int, day: Int, year: Int, skipsSaturday: Bool = false) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        switch calendar.component(.weekday, from: date) {
        case 7: return skipsSaturday ? nil : calendar.date(byAdding: .day, value: -1, to: date)
        case 1: return calendar.date(byAdding: .day, value: 1, to: date)
        default: return date
        }
    }

    private func nthWeekday(ordinal: Int, weekday: Int, month: Int, year: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: ordinal))
    }

    private func goodFriday(in year: Int) -> Date? {
        guard let easter = easterSunday(in: year) else { return nil }
        return calendar.date(byAdding: .day, value: -2, to: easter)
    }

    private func easterSunday(in year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

struct MarketCalendars: Sendable {
    private let usEquities = USEquityCalendar()
    private let alwaysOpen = AlwaysOpenCalendar()

    func session(for assetClass: AssetClass, at date: Date) -> MarketSession {
        switch assetClass.calendarKind {
        case .alwaysOpen: alwaysOpen.session(at: date)
        case .usEquities: usEquities.session(at: date)
        }
    }
}
