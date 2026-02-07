import Foundation
import GRDB

enum SyncItemType: String, Codable, Sendable {
    case track
    case album
    case artist
}

struct SyncItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: Int64?
    var itemType: SyncItemType
    var trackId: Int64?
    var albumId: Int64?
    var artistId: Int64?
    var dateAdded: Date

    init(trackId: Int64, dateAdded: Date = Date()) {
        self.id = nil
        self.itemType = .track
        self.trackId = trackId
        self.albumId = nil
        self.artistId = nil
        self.dateAdded = dateAdded
    }

    init(albumId: Int64, dateAdded: Date = Date()) {
        self.id = nil
        self.itemType = .album
        self.trackId = nil
        self.albumId = albumId
        self.artistId = nil
        self.dateAdded = dateAdded
    }

    init(artistId: Int64, dateAdded: Date = Date()) {
        self.id = nil
        self.itemType = .artist
        self.trackId = nil
        self.albumId = nil
        self.artistId = artistId
        self.dateAdded = dateAdded
    }
}

extension SyncItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "syncItem"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
