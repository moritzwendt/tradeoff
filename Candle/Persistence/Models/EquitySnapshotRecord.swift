import Foundation
import SwiftData

@Model
final class EquitySnapshotRecord {
    var time: Date
    var equity: Decimal
    var cash: Decimal

    init(time: Date, equity: Decimal, cash: Decimal) {
        self.time = time
        self.equity = equity
        self.cash = cash
    }
}
