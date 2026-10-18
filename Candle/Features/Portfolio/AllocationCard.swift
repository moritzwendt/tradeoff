import Charts
import SwiftUI

struct AllocationCard: View {
    let valuation: PortfolioValuation

    private struct Slice: Identifiable {
        let label: String
        let value: Double
        let color: Color

        var id: String { label }
    }

    private var slices: [Slice] {
        var result: [Slice] = valuation.positions.enumerated().map { index, row in
            Slice(
                label: row.holding.instrument.symbol,
                value: row.value.doubleValue,
                color: Theme.palette[index % (Theme.palette.count - 1)]
            )
        }
        if valuation.cash > 0 {
            result.append(Slice(label: "Cash", value: valuation.cash.doubleValue, color: Theme.palette[Theme.palette.count - 1]))
        }
        return result
    }

    var body: some View {
        let items = slices
        let total = items.reduce(0) { $0 + $1.value }

        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Verteilung")
                    .font(.headline)
                HStack(spacing: 20) {
                    Chart(items) { slice in
                        SectorMark(
                            angle: .value("Wert", slice.value),
                            innerRadius: .ratio(0.64),
                            angularInset: 2
                        )
                        .cornerRadius(5)
                        .foregroundStyle(slice.color)
                    }
                    .frame(width: 132, height: 132)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items.prefix(6)) { slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(slice.color)
                                    .frame(width: 8, height: 8)
                                Text(slice.label)
                                    .font(.subheadline)
                                Spacer(minLength: 4)
                                Text(share(slice.value, of: total))
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func share(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "0 %" }
        return Decimal(value / total, scale: 4).formatted(.percent.precision(.fractionLength(0)))
    }
}
