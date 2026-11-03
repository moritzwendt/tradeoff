import Foundation
import SwiftData

enum PersistenceController {
    static let storeName = "TradeOff.store"
    static let legacyStoreName = "default.store"

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let directory = URL.applicationSupportDirectory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            removeLegacyStore(in: directory)
            configuration = ModelConfiguration(url: directory.appending(path: storeName))
        }
        return try ModelContainer(
            for: AccountRecord.self,
            FillRecord.self,
            PositionRecord.self,
            WatchlistEntry.self,
            EquitySnapshotRecord.self,
            configurations: configuration
        )
    }

    private static func removeLegacyStore(in directory: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: directory.appending(path: legacyStoreName + suffix))
        }
    }
}
