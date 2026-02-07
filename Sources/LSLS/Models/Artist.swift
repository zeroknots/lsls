import Foundation
import GRDB

struct Artist: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var name: String
}

extension Artist: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "artist"

    static let albums = hasMany(Album.self)
    static let tracks = hasMany(Track.self)

    var albums: QueryInterfaceRequest<Album> {
        request(for: Artist.albums)
    }

    var tracks: QueryInterfaceRequest<Track> {
        request(for: Artist.tracks)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
