import Foundation
import SwiftData
import Testing
@testable import TradeOff

@MainActor
struct DemoSeederTests {
    @Test func seedingBuildsAConsistentPortfolio() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let defaults = UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
        let settings = AppSettings(defaults: defaults)
        let hub = QuoteHub(registry: ProviderRegistry([try MockPriceProvider.bundled()]))
        let context = container.mainContext

        await DemoSeeder.seed(context: context, hub: hub, settings: settings)

        let fills = try context.fetch(FetchDescriptor<FillRecord>())
        let positions = try context.fetch(FetchDescriptor<PositionRecord>())
        let snapshots = try context.fetch(FetchDescriptor<EquitySnapshotRecord>())
        let account = try #require(try context.fetch(FetchDescriptor<AccountRecord>()).first)

        #expect(fills.count == 9)
        #expect(!positions.isEmpty)
        #expect(snapshots.count > 30)
        #expect(account.cash > 0)

        let net = fills.reduce(Decimal(0)) { partial, fill in
            fill.side == .buy ? partial - fill.total : partial + fill.total
        }
        #expect(account.cash == account.startingBalance + net)
    }

    @Test func seedingTwiceDoesNotDuplicate() async throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let defaults = UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
        let settings = AppSettings(defaults: defaults)
        let hub = QuoteHub(registry: ProviderRegistry([try MockPriceProvider.bundled()]))
        let context = container.mainContext

        await DemoSeeder.seed(context: context, hub: hub, settings: settings)
        await DemoSeeder.seed(context: context, hub: hub, settings: settings)

        #expect(try context.fetch(FetchDescriptor<FillRecord>()).count == 9)
        #expect(try context.fetch(FetchDescriptor<AccountRecord>()).count == 1)
    }
}
