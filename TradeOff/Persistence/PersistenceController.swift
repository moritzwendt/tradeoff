import Foundation
import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: AccountRecord.self,
            FillRecord.self,
            PositionRecord.self,
            WatchlistEntry.self,
            EquitySnapshotRecord.self,
            configurations: configuration
        )
    }
}
