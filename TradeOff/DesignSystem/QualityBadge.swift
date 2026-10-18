import SwiftUI

struct QualityBadge: View {
    let quality: QuoteQuality

    var body: some View {
        let color = Theme.color(for: quality)
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(quality.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: .capsule)
    }
}

struct MarketSessionBadge: View {
    let session: MarketSession

    var body: some View {
        let color = session.isOpen ? Theme.positive : Theme.textSecondary
        HStack(spacing: 6) {
            Image(systemName: session.isOpen ? "clock" : "moon.zzz")
                .font(.system(size: 10, weight: .bold))
            Text(session.isOpen ? "Geöffnet" : "Geschlossen")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: .capsule)
    }
}
