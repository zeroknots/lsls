import Foundation
import GRDB

struct Track: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var filePath: String
    var title: String
    var albumId: Int64?
    var artistId: Int64?
    var genre: String?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    var fileSize: Int64?
    var dateAdded: Date
    var playCount: Int
    var lastPlayedAt: Date?
    var isFavorite: Bool
}

extension Track: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "track"

    static let album = belongsTo(Album.self)
    static let artist = belongsTo(Artist.self)

    var album: QueryInterfaceRequest<Album> {
        request(for: Track.album)
    }

    var artist: QueryInterfaceRequest<Artist> {
        request(for: Track.artist)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
