import Foundation
import Testing
@testable import TradeOff

struct MarketCalendarTests {
    private let calendar = USEquityCalendar()
    private let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test func isOpenDuringRegularSession() {
        #expect(calendar.session(at: date(2026, 10, 19, 10, 0)).isOpen)
        #expect(calendar.session(at: date(2026, 10, 19, 9, 30)).isOpen)
        #expect(calendar.session(at: date(2026, 10, 19, 15, 59)).isOpen)
    }

    @Test func isClosedBeforeOpenAndAfterClose() {
        #expect(!calendar.session(at: date(2026, 10, 19, 9, 29)).isOpen)
        #expect(!calendar.session(at: date(2026, 10, 19, 16, 0)).isOpen)
    }

    @Test func weekendsAreClosedAndReopenOnMonday() {
        let session = calendar.session(at: date(2026, 10, 17, 12))
        #expect(session == .closed(opensAt: date(2026, 10, 19, 9, 30)))
    }

    @Test func afterCloseReopensNextTradingDay() {
        let session = calendar.session(at: date(2026, 10, 16, 17))
        #expect(session == .closed(opensAt: date(2026, 10, 19, 9, 30)))
    }

    @Test func openSessionReportsClosingTime() {
        let session = calendar.session(at: date(2026, 10, 19, 11))
        #expect(session == .open(closesAt: date(2026, 10, 19, 16, 0)))
    }

    @Test(arguments: [
        (2026, 1, 1),
        (2026, 1, 19),
        (2026, 2, 16),
        (2026, 4, 3),
        (2026, 5, 25),
        (2026, 6, 19),
        (2026, 7, 3),
        (2026, 9, 7),
        (2026, 11, 26),
        (2026, 12, 25)
    ])
    func holidaysAreClosed(year: Int, month: Int, day: Int) {
        #expect(!calendar.isTradingDay(date(year, month, day)))
    }

    @Test func newYearsOnSaturdayDoesNotCloseFriday() {
        #expect(calendar.isTradingDay(date(2027, 12, 31)))
    }

    @Test func ordinaryWeekdaysAreTradingDays() {
        #expect(calendar.isTradingDay(date(2026, 10, 19)))
        #expect(calendar.isTradingDay(date(2026, 11, 27)))
    }

    @Test func juneteenthWasNotAHolidayBefore2022() {
        #expect(calendar.isTradingDay(date(2021, 6, 18)))
    }

    @Test func calendarsSelectBehaviorByAssetClass() {
        let calendars = MarketCalendars()
        let saturday = date(2026, 10, 17, 12)
        #expect(calendars.session(for: .crypto, at: saturday) == .always)
        #expect(calendars.session(for: .memeCoin, at: saturday) == .always)
        #expect(!calendars.session(for: .stock, at: saturday).isOpen)
        #expect(!calendars.session(for: .etf, at: saturday).isOpen)
    }

    @Test func dayAfterThanksgivingClosesAtOne() {
        #expect(calendar.session(at: date(2026, 11, 27, 12, 59)) == .open(closesAt: date(2026, 11, 27, 13, 0)))
        #expect(calendar.session(at: date(2026, 11, 27, 13, 0)) == .closed(opensAt: date(2026, 11, 30, 9, 30)))
    }

    @Test func christmasEveClosesEarlyOnWeekdays() {
        #expect(calendar.session(at: date(2026, 12, 24, 12, 0)) == .open(closesAt: date(2026, 12, 24, 13, 0)))
        #expect(!calendar.session(at: date(2026, 12, 24, 14, 0)).isOpen)
        #expect(calendar.session(at: date(2024, 12, 24, 12, 0)) == .open(closesAt: date(2024, 12, 24, 13, 0)))
    }

    @Test func christmasEveOnAWeekendOrObservedHolidayHasNoEarlyClose() {
        #expect(!calendar.isEarlyClose(date(2022, 12, 24)))
        #expect(!calendar.isEarlyClose(date(2027, 12, 24)))
        #expect(!calendar.session(at: date(2027, 12, 24, 11, 0)).isOpen)
    }

    @Test func julyThirdClosesEarlyWhenJulyFourthIsAWeekday() {
        #expect(calendar.session(at: date(2025, 7, 3, 12, 30)) == .open(closesAt: date(2025, 7, 3, 13, 0)))
        #expect(calendar.session(at: date(2023, 7, 3, 12, 30)) == .open(closesAt: date(2023, 7, 3, 13, 0)))
        #expect(!calendar.session(at: date(2025, 7, 3, 13, 30)).isOpen)
    }

    @Test func julyThirdIsAFullHolidayWhenJulyFourthIsASaturday() {
        #expect(!calendar.session(at: date(2026, 7, 3, 11, 0)).isOpen)
        #expect(calendar.session(at: date(2026, 7, 2, 15, 0)) == .open(closesAt: date(2026, 7, 2, 16, 0)))
    }

    @Test func regularDaysStillCloseAtFour() {
        #expect(!calendar.isEarlyClose(date(2026, 11, 4)))
        #expect(calendar.session(at: date(2026, 11, 4, 15, 0)) == .open(closesAt: date(2026, 11, 4, 16, 0)))
    }
}
