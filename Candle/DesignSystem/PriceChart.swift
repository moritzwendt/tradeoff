import Charts
import SwiftUI

struct PriceChart: View {
    let candles: [Candlestick]
    let style: ChartStyle
    let range: ChartRange
    let tint: Color
    @Binding var selectedIndex: Int?
    @State private var rawSelection: Double?

    private struct Point: Identifiable {
        let id: Int
        let x: Double
        let open: Double
        let high: Double
        let low: Double
        let close: Double

        var isRising: Bool { close >= open }
    }

    var body: some View {
        let points = candles.enumerated().map { index, candle in
            Point(
                id: index,
                x: Double(index),
                open: candle.open.doubleValue,
                high: candle.high.doubleValue,
                low: candle.low.doubleValue,
                close: candle.close.doubleValue
            )
        }
        let bounds = yBounds(points)

        Chart {
            if style == .line {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Zeit", point.x),
                        yStart: .value("Basis", bounds.lowerBound),
                        yEnd: .value("Preis", point.close)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                    LineMark(x: .value("Zeit", point.x), y: .value("Preis", point.close))
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            } else {
                ForEach(points) { point in
                    let color = point.isRising ? Theme.positive : Theme.negative
                    RuleMark(
                        x: .value("Zeit", point.x),
                        yStart: .value("Tief", point.low),
                        yEnd: .value("Hoch", point.high)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(color)
                    RectangleMark(
                        xStart: .value("Von", point.x - 0.32),
                        xEnd: .value("Bis", point.x + 0.32),
                        yStart: .value("Eröffnung", point.open),
                        yEnd: .value("Schluss", point.close)
                    )
                    .foregroundStyle(color)
                }
            }

            if let last = points.last {
                RuleMark(y: .value("Letzter Kurs", last.close))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 4]))
                    .foregroundStyle(tint.opacity(0.55))
            }

            if let index = selectedIndex, points.indices.contains(index) {
                RuleMark(x: .value("Auswahl", points[index].x))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.white.opacity(0.35))
                if style == .line {
                    PointMark(x: .value("Zeit", points[index].x), y: .value("Preis", points[index].close))
                        .symbolSize(90)
                        .foregroundStyle(tint)
                }
            }
        }
        .chartXScale(domain: -0.5 ... Double(max(points.count - 1, 0)) + 0.5)
        .chartYScale(domain: bounds)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let position = value.as(Double.self) {
                        let index = Int(position.rounded())
                        if candles.indices.contains(index) {
                            Text(TimeFormat.axis(candles[index].time, range: range))
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(PriceFormatter.axis(price))
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartXSelection(value: $rawSelection)
        .onChange(of: rawSelection) { _, newValue in
            guard let newValue, !points.isEmpty else {
                selectedIndex = nil
                return
            }
            selectedIndex = min(max(Int(newValue.rounded()), 0), points.count - 1)
        }
        .haptic(.selection, trigger: selectedIndex)
    }

    private func yBounds(_ points: [Point]) -> ClosedRange<Double> {
        guard let low = points.map(\.low).min(), let high = points.map(\.high).max() else {
            return 0 ... 1
        }
        let padding = max((high - low) * 0.08, high * 0.0005)
        return (low - padding) ... (high + padding)
    }
}
