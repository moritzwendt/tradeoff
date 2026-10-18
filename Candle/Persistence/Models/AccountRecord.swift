import Foundation
import SwiftData

@Model
final class AccountRecord {
    var startingBalance: Decimal
    var cash: Decimal
    var realizedPnL: Decimal
    var totalFees: Decimal
    var currency: String
    var createdAt: Date

    init(startingBalance: Decimal, currency: String = "USD", createdAt: Date = Date()) {
        self.startingBalance = startingBalance
        self.cash = startingBalance
        self.realizedPnL = 0
        self.totalFees = 0
        self.currency = currency
        self.createdAt = createdAt
    }

    var snapshot: AccountSnapshot {
        AccountSnapshot(
            cash: cash,
            startingBalance: startingBalance,
            realizedPnL: realizedPnL,
            totalFees: totalFees
        )
    }
}
