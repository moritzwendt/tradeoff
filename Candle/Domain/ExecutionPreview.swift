import Foundation

struct ExecutionPreview: Equatable, Sendable {
    let side: OrderSide
    let quantity: Decimal
    let referencePrice: Decimal
    let executionPrice: Decimal
    let slippageFraction: Decimal
    let slippageCost: Decimal
    let gross: Decimal
    let fee: Decimal
    let total: Decimal
    let spreadFraction: Decimal
    let quality: QuoteQuality
    let isSyntheticSpread: Bool
    let quoteTimestamp: Date
}
