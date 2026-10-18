import SwiftUI

enum Theme {
    static let background = Color(red: 0.027, green: 0.031, blue: 0.043)
    static let stroke = Color.white.opacity(0.08)
    static let fill = Color.white.opacity(0.06)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let positive = Color(red: 0.20, green: 0.86, blue: 0.58)
    static let negative = Color(red: 1.0, green: 0.37, blue: 0.43)
    static let accent = Color(red: 0.45, green: 0.62, blue: 1.0)
    static let simulation = Color(red: 1.0, green: 0.74, blue: 0.30)
    static let cornerRadius: CGFloat = 26
    static let screenPadding: CGFloat = 16

    static let palette: [Color] = [
        Color(red: 0.45, green: 0.62, blue: 1.0),
        Color(red: 0.30, green: 0.80, blue: 0.80),
        Color(red: 1.0, green: 0.66, blue: 0.28),
        Color(red: 0.86, green: 0.48, blue: 0.95),
        Color(red: 0.38, green: 0.86, blue: 0.55),
        Color(red: 1.0, green: 0.45, blue: 0.50),
        Color(red: 0.95, green: 0.85, blue: 0.40),
        Color(red: 0.60, green: 0.65, blue: 0.75)
    ]

    static func pnl(_ value: Decimal) -> Color {
        if value > 0 { return positive }
        if value < 0 { return negative }
        return textSecondary
    }

    static func tint(for assetClass: AssetClass) -> Color {
        switch assetClass {
        case .stock: Color(red: 0.45, green: 0.62, blue: 1.0)
        case .etf: Color(red: 0.30, green: 0.80, blue: 0.80)
        case .crypto: Color(red: 1.0, green: 0.66, blue: 0.28)
        case .memeCoin: Color(red: 0.86, green: 0.48, blue: 0.95)
        }
    }

    static func color(for quality: QuoteQuality) -> Color {
        switch quality {
        case .live: positive
        case .delayed: Color(red: 1.0, green: 0.84, blue: 0.35)
        case .simulated: simulation
        }
    }
}
