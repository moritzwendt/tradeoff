import SwiftUI

struct SkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2.4, style: .continuous)
            .fill(Theme.surfaceRaised)
            .frame(width: width, height: height)
            .shimmering()
    }
}

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: proxy.size.width * phase)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }

    func placeholder(_ isActive: Bool) -> some View {
        redacted(reason: isActive ? .placeholder : [])
            .shimmering(if: isActive)
    }

    @ViewBuilder
    private func shimmering(if isActive: Bool) -> some View {
        if isActive {
            shimmering()
        } else {
            self
        }
    }

    func appearsAfter(_ delay: Duration) -> some View {
        modifier(DelayedAppearance(delay: delay))
    }
}

private struct DelayedAppearance: ViewModifier {
    let delay: Duration
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .task {
                try? await Task.sleep(for: delay)
                withAnimation(.easeOut(duration: 0.2)) { isVisible = true }
            }
    }
}

struct ChartPlaceholder: View {
    let values: [Double]?
    var color: Color = Theme.textTertiary

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(height: 0.5)
                }
            }
            if let values, values.count > 1 {
                Sparkline(values: values, color: color.opacity(0.6))
                    .padding(.vertical, 24)
            } else {
                WavePlaceholder()
                    .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(.vertical, 40)
            }
        }
        .shimmering()
        .accessibilityHidden(true)
    }
}

private struct WavePlaceholder: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 40
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let wave = sin(progress * .pi * 3.2) * 0.22 + sin(progress * .pi * 7.5) * 0.06 - (progress - 0.5) * 0.35
            let point = CGPoint(x: rect.minX + rect.width * progress, y: rect.midY - rect.height * wave)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
