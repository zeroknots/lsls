import Foundation
import GRDB

struct SyncLog: Codable, Identifiable, Equatable, Sendable {
    var id: Int64?
    var trackId: Int64
    var devicePath: String
    var syncedAt: Date
    var fileSize: Int64
}

extension SyncLog: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "syncLog"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
