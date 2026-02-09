import Foundation
import GRDB

struct PodcastSyncItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: Int64?
    var podcastId: Int64
    var dateAdded: Date

    init(podcastId: Int64, dateAdded: Date = Date()) {
        self.id = nil
        self.podcastId = podcastId
        self.dateAdded = dateAdded
    }
}

extension PodcastSyncItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "podcastSyncItem"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
