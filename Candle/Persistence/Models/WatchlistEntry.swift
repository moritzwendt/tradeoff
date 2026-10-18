import Foundation
import SwiftData

@Model
final class WatchlistEntry {
    @Attribute(.unique) var instrumentID: String
    var instrument: Instrument
    var sortIndex: Int
    var addedAt: Date

    init(instrument: Instrument, sortIndex: Int, addedAt: Date = Date()) {
        instrumentID = instrument.id
        self.instrument = instrument
        self.sortIndex = sortIndex
        self.addedAt = addedAt
    }
}
