import SwiftUI

enum Theme {
    static let background = Color(white: 0.04)
    static let surface = Color(white: 0.10)
    static let surfaceRaised = Color(white: 0.15)
    static let separator = Color.white.opacity(0.08)
    static let stroke = separator
    static let fill = surface
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)
    static let positive = Color(red: 0.20, green: 0.78, blue: 0.47)
    static let negative = Color(red: 0.98, green: 0.30, blue: 0.34)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.25)
    static let accent = Color(red: 0.40, green: 0.60, blue: 1.0)
    static let cornerRadius: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let rowHeight: CGFloat = 64

    static let palette: [Color] = [
        Color(red: 0.55, green: 0.65, blue: 0.95),
        Color(red: 0.45, green: 0.78, blue: 0.78),
        Color(red: 0.92, green: 0.70, blue: 0.40),
        Color(red: 0.78, green: 0.58, blue: 0.90),
        Color(red: 0.55, green: 0.80, blue: 0.55),
        Color(red: 0.92, green: 0.55, blue: 0.58),
        Color(red: 0.88, green: 0.82, blue: 0.50),
        Color.white.opacity(0.35)
    ]

    static func pnl(_ value: Decimal) -> Color {
        if value > 0 { return positive }
        if value < 0 { return negative }
        return textSecondary
    }
}
