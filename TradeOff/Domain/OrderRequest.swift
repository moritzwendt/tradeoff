import Foundation

struct OrderRequest: Equatable, Sendable {
    let instrumentID: InstrumentID
    let side: OrderSide
    let quantity: Decimal
}
