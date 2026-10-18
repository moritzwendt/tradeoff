import Foundation

enum ChartStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case line
    case candles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line: "Linie"
        case .candles: "Kerzen"
        }
    }

    var systemImage: String {
        switch self {
        case .line: "chart.xyaxis.line"
        case .candles: "chart.bar.xaxis"
        }
    }
}
