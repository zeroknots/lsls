import Foundation
import GRDB

struct Album: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var title: String
    var artistId: Int64?
    var year: Int?
    var artworkPath: String?
}

extension Album: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "album"

    static let artist = belongsTo(Artist.self)
    static let tracks = hasMany(Track.self)

    var artist: QueryInterfaceRequest<Artist> {
        request(for: Album.artist)
    }

    var tracks: QueryInterfaceRequest<Track> {
        request(for: Album.tracks)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
