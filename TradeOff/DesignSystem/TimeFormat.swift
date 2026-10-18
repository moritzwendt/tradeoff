import Foundation

enum TimeFormat {
    static func axis(_ date: Date, range: ChartRange) -> String {
        switch range {
        case .day: date.formatted(.dateTime.hour().minute())
        case .week: date.formatted(.dateTime.weekday(.abbreviated))
        case .month, .quarter: date.formatted(.dateTime.day().month(.abbreviated))
        case .year: date.formatted(.dateTime.month(.abbreviated))
        case .max: date.formatted(.dateTime.year())
        }
    }

    static func detail(_ date: Date, range: ChartRange) -> String {
        switch range {
        case .day, .week: date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        case .month: date.formatted(.dateTime.day().month(.abbreviated).hour())
        case .quarter, .year, .max: date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Heute" }
        if Calendar.current.isDateInYesterday(date) { return "Gestern" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
