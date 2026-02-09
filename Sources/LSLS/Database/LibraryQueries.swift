import Foundation
import GRDB
import CoreTransferable

struct AlbumInfo: Codable, FetchableRecord, Equatable, Hashable, Identifiable {
    var album: Album
    var artist: Artist?
    var id: Int64? { album.id }
}

struct TrackInfo: Codable, FetchableRecord, Equatable, Hashable, Identifiable {
    var track: Track
    var album: Album?
    var artist: Artist?
    var id: Int64? { track.id }
}

enum LibraryDragItem: Codable, Transferable, Hashable {
    case track(TrackInfo)
    case album(AlbumInfo)
    case artist(Artist)

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

enum CommandPaletteResultKind: Equatable, Hashable {
    case track(TrackInfo)
    case album(AlbumInfo)
    case artist(Artist)
}

struct CommandPaletteResult: Identifiable, Equatable, Hashable {
    let id: String
    let kind: CommandPaletteResultKind
    let title: String
    let subtitle: String
    let iconName: String
}

enum LibraryQueries {
    static func allAlbums(in db: Database) throws -> [AlbumInfo] {
        let request = Album
            .including(optional: Album.artist)
            .order(Album.Columns.title)
        return try AlbumInfo.fetchAll(db, request)
    }

    static func allArtists(in db: Database) throws -> [Artist] {
        try Artist
            .order(Artist.Columns.name)
            .fetchAll(db)
    }

    static func allTracks(in db: Database) throws -> [TrackInfo] {
        let request = Track
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .order(Track.Columns.title)
        return try TrackInfo.fetchAll(db, request)
    }

    static func tracksForAlbum(_ albumId: Int64, in db: Database) throws -> [TrackInfo] {
        let request = Track
            .filter(Track.Columns.albumId == albumId)
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .order(Track.Columns.discNumber, Track.Columns.trackNumber)
        return try TrackInfo.fetchAll(db, request)
    }

    static func tracksForArtist(_ artistId: Int64, in db: Database) throws -> [TrackInfo] {
        let request = Track
            .filter(Track.Columns.artistId == artistId)
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .order(Track.Columns.albumId, Track.Columns.discNumber, Track.Columns.trackNumber)
        return try TrackInfo.fetchAll(db, request)
    }

    static func albumsForArtist(_ artistId: Int64, in db: Database) throws -> [AlbumInfo] {
        let request = Album
            .filter(Album.Columns.artistId == artistId)
            .including(optional: Album.artist)
            .order(Album.Columns.year)
        return try AlbumInfo.fetchAll(db, request)
    }

    static func recentlyAdded(limit: Int = 50, in db: Database) throws -> [AlbumInfo] {
        let recentAlbumIds = try Track
            .select(Track.Columns.albumId, max(Track.Columns.dateAdded))
            .group(Track.Columns.albumId)
            .order(max(Track.Columns.dateAdded).desc)
            .limit(limit)
            .asRequest(of: Row.self)
            .fetchAll(db)
            .compactMap { $0[Track.Columns.albumId] as Int64? }

        guard !recentAlbumIds.isEmpty else { return [] }

        let request = Album
            .filter(recentAlbumIds.contains(Album.Columns.id))
            .including(optional: Album.artist)
        return try AlbumInfo.fetchAll(db, request)
    }

    static func search(_ query: String, in db: Database) throws -> (tracks: [TrackInfo], albums: [AlbumInfo], artists: [Artist]) {
        let pattern = "%\(query)%"

        let tracks = try Track
            .filter(Track.Columns.title.like(pattern))
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .limit(20)
            .asRequest(of: TrackInfo.self)
            .fetchAll(db)

        let albums = try Album
            .filter(Album.Columns.title.like(pattern))
            .including(optional: Album.artist)
            .limit(20)
            .asRequest(of: AlbumInfo.self)
            .fetchAll(db)

        let artists = try Artist
            .filter(Artist.Columns.name.like(pattern))
            .limit(20)
            .fetchAll(db)

        return (tracks, albums, artists)
    }

    static func commandPaletteSearch(_ query: String, in db: Database) throws -> [CommandPaletteResult] {
        guard !query.isEmpty else { return [] }
        let tokens = query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        // Step 1: Use raw SQL to find matching track IDs with cross-field token matching
        let tokenConditions = tokens.map { _ in
            "(track.title LIKE ? OR artist.name LIKE ? OR album.title LIKE ?)"
        }.joined(separator: " AND ")
        var arguments: [DatabaseValueConvertible] = []
        for token in tokens {
            let pattern = "%\(token)%"
            arguments.append(contentsOf: [pattern, pattern, pattern])
        }

        let scoreExpr = tokens.map { _ in
            "(CASE WHEN track.title LIKE ? THEN 1 ELSE 0 END)"
        }.joined(separator: " + ")
        for token in tokens {
            arguments.append("%\(token)%")
        }

        arguments.append(20)

        let trackIds = try Int64.fetchAll(db, sql: """
            SELECT track.id
            FROM track
            LEFT JOIN album ON album.id = track.albumId
            LEFT JOIN artist ON artist.id = track.artistId
            WHERE \(tokenConditions)
            ORDER BY \(scoreExpr) DESC, track.title ASC
            LIMIT ?
            """, arguments: StatementArguments(arguments))

        guard !trackIds.isEmpty else { return [] }

        // Step 2: Fetch full TrackInfo via GRDB query interface (proper column scoping)
        let allTracks = try Track
            .filter(trackIds.contains(Track.Columns.id))
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .asRequest(of: TrackInfo.self)
            .fetchAll(db)

        // Preserve the ranked order from the SQL query
        let trackById = Dictionary(uniqueKeysWithValues: allTracks.compactMap { t in
            t.track.id.map { ($0, t) }
        })
        let tracks = trackIds.compactMap { trackById[$0] }

        var results: [CommandPaletteResult] = []
        var seenArtistIds = Set<Int64>()
        var seenAlbumIds = Set<Int64>()

        // Extract unique artists and albums from matched tracks
        for trackInfo in tracks {
            if let artist = trackInfo.artist, let artistId = artist.id, !seenArtistIds.contains(artistId) {
                let artistMatches = tokens.contains { token in
                    artist.name.localizedCaseInsensitiveContains(token)
                }
                if artistMatches && seenArtistIds.count < 3 {
                    seenArtistIds.insert(artistId)
                    results.append(CommandPaletteResult(
                        id: "artist-\(artistId)",
                        kind: .artist(artist),
                        title: artist.name,
                        subtitle: "Artist",
                        iconName: "music.mic"
                    ))
                }
            }

            if let album = trackInfo.album, let albumId = album.id, !seenAlbumIds.contains(albumId) {
                let albumMatches = tokens.contains { token in
                    album.title.localizedCaseInsensitiveContains(token)
                }
                if albumMatches && seenAlbumIds.count < 3 {
                    seenAlbumIds.insert(albumId)
                    results.append(CommandPaletteResult(
                        id: "album-\(albumId)",
                        kind: .album(AlbumInfo(album: album, artist: trackInfo.artist)),
                        title: album.title,
                        subtitle: trackInfo.artist?.name ?? "Album",
                        iconName: "opticaldisc"
                    ))
                }
            }
        }

        // Add track results
        for trackInfo in tracks {
            let artistName = trackInfo.artist?.name
            let albumTitle = trackInfo.album?.title
            let subtitle: String
            switch (artistName, albumTitle) {
            case let (a?, b?): subtitle = "\(a) — \(b)"
            case let (a?, nil): subtitle = a
            case let (nil, b?): subtitle = b
            case (nil, nil): subtitle = ""
            }
            results.append(CommandPaletteResult(
                id: "track-\(trackInfo.track.id ?? 0)",
                kind: .track(trackInfo),
                title: trackInfo.track.title,
                subtitle: subtitle,
                iconName: "music.note"
            ))
        }

        return results
    }

    static func playlistTracks(_ playlistId: Int64, in db: Database) throws -> [TrackInfo] {
        let request = Track
            .joining(required: Track.hasOne(PlaylistTrack.self).filter(PlaylistTrack.Columns.playlistId == playlistId))
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .order(sql: "(SELECT position FROM playlistTrack WHERE playlistTrack.trackId = track.id AND playlistTrack.playlistId = ?)", arguments: [playlistId])
        return try TrackInfo.fetchAll(db, request)
    }

    static func allPlaylists(in db: Database) throws -> [Playlist] {
        try Playlist
            .order(Playlist.Columns.name)
            .fetchAll(db)
    }

    @discardableResult
    static func findOrCreateArtist(name: String, in db: Database) throws -> Artist {
        if let existing = try Artist.filter(Artist.Columns.name == name).fetchOne(db) {
            return existing
        }
        var artist = Artist(name: name)
        try artist.insert(db)
        return artist
    }

    @discardableResult
    static func findOrCreateAlbum(title: String, artistId: Int64?, in db: Database) throws -> Album {
        var query = Album.filter(Album.Columns.title == title)
        if let artistId {
            query = query.filter(Album.Columns.artistId == artistId)
        }
        if let existing = try query.fetchOne(db) {
            return existing
        }
        var album = Album(title: title, artistId: artistId)
        try album.insert(db)
        return album
    }

    // MARK: - Sync List

    static func allSyncItems(in db: Database) throws -> [SyncItem] {
        try SyncItem
            .order(SyncItem.Columns.dateAdded.desc)
            .fetchAll(db)
    }

    static func syncItemExists(itemType: SyncItemType, trackId: Int64? = nil, albumId: Int64? = nil, artistId: Int64? = nil, in db: Database) throws -> Bool {
        var request = SyncItem.filter(SyncItem.Columns.itemType == itemType.rawValue)
        if let trackId { request = request.filter(SyncItem.Columns.trackId == trackId) }
        if let albumId { request = request.filter(SyncItem.Columns.albumId == albumId) }
        if let artistId { request = request.filter(SyncItem.Columns.artistId == artistId) }
        return try request.fetchOne(db) != nil
    }

    static func resolvedTracksForSync(in db: Database) throws -> [TrackInfo] {
        var trackIds = Set<Int64>()

        let trackItems = try SyncItem
            .filter(SyncItem.Columns.itemType == SyncItemType.track.rawValue)
            .fetchAll(db)
        for item in trackItems {
            if let id = item.trackId { trackIds.insert(id) }
        }

        let albumItems = try SyncItem
            .filter(SyncItem.Columns.itemType == SyncItemType.album.rawValue)
            .fetchAll(db)
        for item in albumItems {
            if let albumId = item.albumId {
                let tracks = try Track
                    .filter(Track.Columns.albumId == albumId)
                    .fetchAll(db)
                for track in tracks {
                    if let id = track.id { trackIds.insert(id) }
                }
            }
        }

        let artistItems = try SyncItem
            .filter(SyncItem.Columns.itemType == SyncItemType.artist.rawValue)
            .fetchAll(db)
        for item in artistItems {
            if let artistId = item.artistId {
                let tracks = try Track
                    .filter(Track.Columns.artistId == artistId)
                    .fetchAll(db)
                for track in tracks {
                    if let id = track.id { trackIds.insert(id) }
                }
            }
        }

        guard !trackIds.isEmpty else { return [] }

        let request = Track
            .filter(trackIds.contains(Track.Columns.id))
            .including(optional: Track.album)
            .including(optional: Track.artist)
            .order(Track.Columns.artistId, Track.Columns.albumId, Track.Columns.discNumber, Track.Columns.trackNumber)
        return try TrackInfo.fetchAll(db, request)
    }

    static func allSyncLogs(in db: Database) throws -> [SyncLog] {
        try SyncLog.fetchAll(db)
    }

    // MARK: - Mutations

    static func deleteTrack(_ trackId: Int64, in db: Database) throws {
        _ = try Track.deleteOne(db, id: trackId)
        try deleteOrphans(in: db)
    }

    static func deleteAlbum(_ albumId: Int64, in db: Database) throws {
        // Delete tracks first (track→album FK is SET NULL, not CASCADE)
        try Track
            .filter(Track.Columns.albumId == albumId)
            .deleteAll(db)
        _ = try Album.deleteOne(db, id: albumId)
        try deleteOrphans(in: db)
    }

    static func updateTrack(
        _ trackId: Int64,
        title: String,
        artistId: Int64?,
        in db: Database
    ) throws {
        guard var track = try Track.fetchOne(db, id: trackId) else { return }
        track.title = title
        track.artistId = artistId
        try track.update(db)
        try deleteOrphans(in: db)
    }

    static func deleteOrphans(in db: Database) throws {
        // For albums where all tracks share one artist different from the album's artist,
        // merge tracks into an existing album (same title + artist) or re-assign the album
        let staleAlbums = try Row.fetchAll(db, sql: """
            SELECT a.id, a.title,
                   (SELECT DISTINCT t.artistId FROM track t WHERE t.albumId = a.id AND t.artistId IS NOT NULL) as newArtistId
            FROM album a
            WHERE (SELECT COUNT(DISTINCT t.artistId) FROM track t WHERE t.albumId = a.id AND t.artistId IS NOT NULL) = 1
              AND a.artistId != (SELECT DISTINCT t.artistId FROM track t WHERE t.albumId = a.id AND t.artistId IS NOT NULL)
            """)
        for row in staleAlbums {
            let oldAlbumId: Int64 = row["id"]
            let title: String = row["title"]
            let newArtistId: Int64 = row["newArtistId"]

            // Check if target album already exists
            if let targetAlbum = try Album
                .filter(Album.Columns.title == title)
                .filter(Album.Columns.artistId == newArtistId)
                .fetchOne(db) {
                // Merge: move tracks to existing album
                try db.execute(sql: "UPDATE track SET albumId = ? WHERE albumId = ?",
                               arguments: [targetAlbum.id, oldAlbumId])
                _ = try Album.deleteOne(db, id: oldAlbumId)
            } else {
                // No conflict: just update the album's artist
                try db.execute(sql: "UPDATE album SET artistId = ? WHERE id = ?",
                               arguments: [newArtistId, oldAlbumId])
            }
        }

        // Delete albums that have no tracks
        try db.execute(sql: """
            DELETE FROM album
            WHERE id NOT IN (SELECT DISTINCT albumId FROM track WHERE albumId IS NOT NULL)
            """)
        // Delete artists that have no tracks and no albums
        try db.execute(sql: """
            DELETE FROM artist
            WHERE id NOT IN (SELECT DISTINCT artistId FROM track WHERE artistId IS NOT NULL)
              AND id NOT IN (SELECT DISTINCT artistId FROM album WHERE artistId IS NOT NULL)
            """)
    }

    // MARK: - Favorites

    static func toggleFavorite(trackId: Int64, in db: Database) throws {
        try db.execute(
            sql: "UPDATE track SET isFavorite = NOT isFavorite WHERE id = ?",
            arguments: [trackId]
        )
    }

    static func isFavorite(trackId: Int64, in db: Database) throws -> Bool {
        try Bool.fetchOne(db, sql: "SELECT isFavorite FROM track WHERE id = ?", arguments: [trackId]) ?? false
    }

    // MARK: - Play Tracking

    static func recordPlay(trackId: Int64, in db: Database) throws {
        try db.execute(
            sql: "UPDATE track SET playCount = playCount + 1, lastPlayedAt = ? WHERE id = ?",
            arguments: [Date(), trackId]
        )
    }

    // MARK: - Smart Playlists

    static func allSmartPlaylists(in db: Database) throws -> [SmartPlaylist] {
        try SmartPlaylist
            .order(SmartPlaylist.Columns.name)
            .fetchAll(db)
    }

    static func rulesForSmartPlaylist(_ smartPlaylistId: Int64, in db: Database) throws -> [SmartPlaylistRule] {
        try SmartPlaylistRule
            .filter(SmartPlaylistRule.Columns.smartPlaylistId == smartPlaylistId)
            .order(SmartPlaylistRule.Columns.position)
            .fetchAll(db)
    }

    static func smartPlaylistTracks(_ rules: [SmartPlaylistRule], in db: Database) throws -> [TrackInfo] {
        guard !rules.isEmpty else { return [] }

        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []
        var needsArtistJoin = false

        for rule in rules {
            switch rule.field {
            case .playCount:
                let op = sqlOperator(rule.operator)
                conditions.append("track.playCount \(op) ?")
                arguments.append(Int(rule.value) ?? 0)

            case .isFavorite:
                conditions.append("track.isFavorite = 1")

            case .artist:
                needsArtistJoin = true
                let op = rule.operator
                if op == .contains {
                    conditions.append("artist.name LIKE ?")
                    arguments.append("%\(rule.value)%")
                } else {
                    conditions.append("artist.name = ?")
                    arguments.append(rule.value)
                }

            case .genre:
                if rule.operator == .contains {
                    conditions.append("track.genre LIKE ?")
                    arguments.append("%\(rule.value)%")
                } else {
                    conditions.append("track.genre = ?")
                    arguments.append(rule.value)
                }

            case .dateAdded:
                let op = sqlOperator(rule.operator)
                conditions.append("track.dateAdded \(op) ?")
                arguments.append(rule.value)

            case .lastPlayedAt:
                let op = sqlOperator(rule.operator)
                conditions.append("track.lastPlayedAt \(op) ?")
                arguments.append(rule.value)

            case .bpm:
                let op = sqlOperator(rule.operator)
                conditions.append("track.bpm \(op) ?")
                arguments.append(Double(rule.value) ?? 0)
            }
        }

        let whereClause = conditions.joined(separator: " AND ")
        let _ = needsArtistJoin ? "" : "LEFT JOIN artist ON artist.id = track.artistId"

        let sql = """
            SELECT track.*, album.*, artist.*
            FROM track
            LEFT JOIN album ON album.id = track.albumId
            LEFT JOIN artist ON artist.id = track.artistId
            WHERE \(whereClause)
            ORDER BY track.playCount DESC, track.title ASC
            """

        return try TrackInfo.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
    }

    private static func sqlOperator(_ op: SmartPlaylistOperator) -> String {
        switch op {
        case .greaterThan: ">"
        case .lessThan: "<"
        case .equals: "="
        case .contains: "LIKE"
        case .isTrue: "="
        }
    }

    static func deleteSmartPlaylist(_ smartPlaylistId: Int64, in db: Database) throws {
        _ = try SmartPlaylist.deleteOne(db, id: smartPlaylistId)
    }

    // MARK: - Playlists

    static func addTrackToPlaylist(
        trackId: Int64,
        playlistId: Int64,
        in db: Database
    ) throws {
        let maxPosition = try Int.fetchOne(
            db,
            PlaylistTrack
                .filter(PlaylistTrack.Columns.playlistId == playlistId)
                .select(max(PlaylistTrack.Columns.position))
        ) ?? 0
        let pt = PlaylistTrack(
            playlistId: playlistId,
            trackId: trackId,
            position: maxPosition + 1
        )
        try pt.insert(db)
    }
}

// Column references
extension Album {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let artistId = Column("artistId")
        static let year = Column("year")
        static let artworkPath = Column("artworkPath")
    }
}

extension Track {
    enum Columns {
        static let id = Column("id")
        static let filePath = Column("filePath")
        static let title = Column("title")
        static let albumId = Column("albumId")
        static let artistId = Column("artistId")
        static let trackNumber = Column("trackNumber")
        static let discNumber = Column("discNumber")
        static let duration = Column("duration")
        static let fileSize = Column("fileSize")
        static let dateAdded = Column("dateAdded")
        static let playCount = Column("playCount")
        static let lastPlayedAt = Column("lastPlayedAt")
        static let isFavorite = Column("isFavorite")
        static let bpm = Column("bpm")
    }
}

extension Artist {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
    }
}

extension Playlist {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let dateCreated = Column("dateCreated")
    }
}

extension PlaylistTrack {
    enum Columns {
        static let playlistId = Column("playlistId")
        static let trackId = Column("trackId")
        static let position = Column("position")
    }
}

extension SyncItem {
    enum Columns {
        static let id = Column("id")
        static let itemType = Column("itemType")
        static let trackId = Column("trackId")
        static let albumId = Column("albumId")
        static let artistId = Column("artistId")
        static let dateAdded = Column("dateAdded")
    }
}

extension SyncLog {
    enum Columns {
        static let id = Column("id")
        static let trackId = Column("trackId")
        static let devicePath = Column("devicePath")
        static let syncedAt = Column("syncedAt")
        static let fileSize = Column("fileSize")
    }
}

extension SmartPlaylist {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let dateCreated = Column("dateCreated")
    }
}

extension SmartPlaylistRule {
    enum Columns {
        static let id = Column("id")
        static let smartPlaylistId = Column("smartPlaylistId")
        static let field = Column("field")
        static let `operator` = Column("operator")
        static let value = Column("value")
        static let position = Column("position")
    }
}

extension Podcast {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let author = Column("author")
        static let feedUrl = Column("feedUrl")
        static let artworkUrl = Column("artworkUrl")
        static let lastFetchedAt = Column("lastFetchedAt")
        static let dateSubscribed = Column("dateSubscribed")
    }
}

extension Episode {
    enum Columns {
        static let id = Column("id")
        static let podcastId = Column("podcastId")
        static let title = Column("title")
        static let audioUrl = Column("audioUrl")
        static let localFilePath = Column("localFilePath")
        static let pubDate = Column("pubDate")
        static let duration = Column("duration")
        static let fileSize = Column("fileSize")
        static let isDownloaded = Column("isDownloaded")
        static let isPlayed = Column("isPlayed")
        static let playbackPosition = Column("playbackPosition")
        static let dateAdded = Column("dateAdded")
    }
}

extension PodcastSyncItem {
    enum Columns {
        static let id = Column("id")
        static let podcastId = Column("podcastId")
        static let dateAdded = Column("dateAdded")
    }
}
