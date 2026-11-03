import SwiftUI

struct MarketSessionBadge: View {
    let session: MarketSession

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isOpen ? Theme.positive : Theme.textTertiary)
                .frame(width: 6, height: 6)
            Text(session.isOpen ? "Börse geöffnet" : "Börse geschlossen")
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
