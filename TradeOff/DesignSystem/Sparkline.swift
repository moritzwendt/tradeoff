import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.22), color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        let sampled = sample(values, limit: 48)
        guard sampled.count > 1, let low = sampled.min(), let high = sampled.max() else { return [] }
        let span = max(high - low, .leastNonzeroMagnitude)
        return sampled.enumerated().map { index, value in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(sampled.count - 1),
                y: size.height - size.height * CGFloat((value - low) / span) * 0.9 - size.height * 0.05
            )
        }
    }

    private func sample(_ values: [Double], limit: Int) -> [Double] {
        guard values.count > limit else { return values }
        let step = Double(values.count - 1) / Double(limit - 1)
        return (0..<limit).map { values[Int((Double($0) * step).rounded())] }
    }
}
