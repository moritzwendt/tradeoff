import Charts
import SwiftUI

struct EquityPoint: Identifiable, Equatable {
    let time: Date
    let value: Double

    var id: Date { time }
}

struct EquityChart: View {
    let points: [EquityPoint]
    let range: ChartRange
    let tint: Color
    @Binding var selectedPoint: EquityPoint?
    @State private var rawDate: Date?

    var body: some View {
        let bounds = yBounds()
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Zeit", point.time),
                    yStart: .value("Basis", bounds.lowerBound),
                    yEnd: .value("Wert", point.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
                LineMark(x: .value("Zeit", point.time), y: .value("Wert", point.value))
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let selected = selectedPoint {
                RuleMark(x: .value("Auswahl", selected.time))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.white.opacity(0.35))
                PointMark(x: .value("Zeit", selected.time), y: .value("Wert", selected.value))
                    .symbolSize(90)
                    .foregroundStyle(tint)
            }
        }
        .chartYScale(domain: bounds)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(TimeFormat.axis(date, range: range))
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(PriceFormatter.axis(amount))
                    }
                }
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartXSelection(value: $rawDate)
        .onChange(of: rawDate) { _, newValue in
            guard let newValue else {
                selectedPoint = nil
                return
            }
            selectedPoint = points.min { abs($0.time.timeIntervalSince(newValue)) < abs($1.time.timeIntervalSince(newValue)) }
        }
        .haptic(.selection, trigger: selectedPoint)
    }

    private func yBounds() -> ClosedRange<Double> {
        guard let low = points.map(\.value).min(), let high = points.map(\.value).max() else {
            return 0 ... 1
        }
        let padding = max((high - low) * 0.12, high * 0.001)
        return (low - padding) ... (high + padding)
    }
}
