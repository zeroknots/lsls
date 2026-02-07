import Foundation
import GRDB

struct Playlist: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var dateCreated: Date

    init(id: Int64? = nil, name: String, dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
    }
}

extension Playlist: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "playlist"

    static let playlistTracks = hasMany(PlaylistTrack.self)
    static let tracks = hasMany(Track.self, through: playlistTracks, using: PlaylistTrack.track)

    var tracks: QueryInterfaceRequest<Track> {
        request(for: Playlist.tracks)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PlaylistTrack: Codable, Equatable {
    var playlistId: Int64
    var trackId: Int64
    var position: Int
}

extension PlaylistTrack: FetchableRecord, PersistableRecord {
    static let databaseTableName = "playlistTrack"

    static let track = belongsTo(Track.self)
    static let playlist = belongsTo(Playlist.self)
}
