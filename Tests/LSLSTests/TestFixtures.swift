import Foundation
import GRDB

@testable import LSLS

enum TestFixtures {
    static let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    static var hasFFmpeg: Bool {
        FileManager.default.fileExists(atPath: ffmpegPath)
    }

    // MARK: - Temp directory

    static func createTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lsls-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - FLAC generation via ffmpeg

    static func generateFlac(
        in directory: URL,
        filename: String = "test.flac",
        title: String = "Test Track",
        artist: String = "Test Artist",
        album: String = "Test Album",
        year: String = "2024",
        track: String = "1/3",
        genre: String = "Rock",
        withArtwork: Bool = false
    ) throws -> URL {
        let outputPath = directory.appendingPathComponent(filename)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        if withArtwork {
            process.arguments = [
                "-f", "lavfi", "-i", "sine=frequency=440:duration=0.5",
                "-f", "lavfi", "-i", "color=c=blue:s=100x100,format=yuvj420p",
                "-frames:v:0", "1",
                "-map", "0:a", "-map", "1:v",
                "-c:a", "flac", "-c:v", "mjpeg",
                "-disposition:v", "attached_pic",
                "-metadata", "title=\(title)",
                "-metadata", "artist=\(artist)",
                "-metadata", "album=\(album)",
                "-metadata", "date=\(year)",
                "-metadata", "track=\(track)",
                "-metadata", "genre=\(genre)",
                "-y", outputPath.path,
            ]
        } else {
            process.arguments = [
                "-f", "lavfi", "-i", "sine=frequency=440:duration=0.5",
                "-c:a", "flac",
                "-metadata", "title=\(title)",
                "-metadata", "artist=\(artist)",
                "-metadata", "album=\(album)",
                "-metadata", "date=\(year)",
                "-metadata", "track=\(track)",
                "-metadata", "genre=\(genre)",
                "-y", outputPath.path,
            ]
        }

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TestFixtures", code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "ffmpeg failed to generate \(filename)"])
        }

        return outputPath
    }

    // MARK: - Test database (same schema as production, temp file)

    static func createTestDatabase(in directory: URL) throws -> DatabasePool {
        let dbPath = directory.appendingPathComponent("test-library.sqlite").path
        let dbPool = try DatabasePool(path: dbPath)

        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "artist") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull().unique()
            }
            try db.create(table: "album") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("artistId", .integer).references("artist", onDelete: .setNull)
                t.column("year", .integer)
                t.column("artworkPath", .text)
                t.uniqueKey(["title", "artistId"])
            }
            try db.create(table: "track") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("filePath", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("albumId", .integer).references("album", onDelete: .setNull)
                t.column("artistId", .integer).references("artist", onDelete: .setNull)
                t.column("trackNumber", .integer)
                t.column("discNumber", .integer).defaults(to: 1)
                t.column("duration", .double).notNull()
                t.column("fileSize", .integer)
                t.column("dateAdded", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "playlist") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("dateCreated", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "playlistTrack") { t in
                t.column("playlistId", .integer).notNull().references("playlist", onDelete: .cascade)
                t.column("trackId", .integer).notNull().references("track", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.primaryKey(["playlistId", "trackId"])
            }
        }

        migrator.registerMigration("v2") { db in
            try db.alter(table: "track") { t in
                t.add(column: "genre", .text)
            }
        }

        migrator.registerMigration("v3") { db in
            try db.create(table: "syncSettings") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
            try db.create(table: "syncItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("itemType", .text).notNull()
                t.column("trackId", .integer).references("track", onDelete: .cascade)
                t.column("albumId", .integer).references("album", onDelete: .cascade)
                t.column("artistId", .integer).references("artist", onDelete: .cascade)
                t.column("dateAdded", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "syncLog") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("trackId", .integer).notNull().references("track", onDelete: .cascade).unique()
                t.column("devicePath", .text).notNull()
                t.column("syncedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("fileSize", .integer).notNull()
            }
        }

        migrator.registerMigration("v4") { db in
            try db.alter(table: "track") { t in
                t.add(column: "playCount", .integer).notNull().defaults(to: 0)
                t.add(column: "lastPlayedAt", .datetime)
                t.add(column: "isFavorite", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "smartPlaylist") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("dateCreated", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(table: "smartPlaylistRule") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("smartPlaylistId", .integer).notNull()
                    .references("smartPlaylist", onDelete: .cascade)
                t.column("field", .text).notNull()
                t.column("operator", .text).notNull()
                t.column("value", .text).notNull()
                t.column("position", .integer).notNull()
            }
        }

        migrator.registerMigration("v5") { db in
            try db.alter(table: "track") { t in
                t.add(column: "bpm", .double)
            }
        }

        try migrator.migrate(dbPool)
        return dbPool
    }

    // MARK: - Seed mock data into test database

    struct SeedResult {
        let artistId: Int64
        let albumIds: [Int64]
        let trackIds: [Int64]
    }

    static func seedMockData(in dbPool: DatabasePool) throws -> SeedResult {
        try dbPool.write { db in
            // Artist
            let artist = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            let artistId = artist.id!

            // Albums
            let opiate = try LibraryQueries.findOrCreateAlbum(
                title: "Opiate", artistId: artistId, in: db)
            var opiateUpdate = opiate
            opiateUpdate.year = 1992
            try opiateUpdate.update(db)

            let undertow = try LibraryQueries.findOrCreateAlbum(
                title: "Undertow", artistId: artistId, in: db)
            var undertowUpdate = undertow
            undertowUpdate.year = 1993
            try undertowUpdate.update(db)

            let aenima = try LibraryQueries.findOrCreateAlbum(
                title: "Ænima", artistId: artistId, in: db)
            var aenimaUpdate = aenima
            aenimaUpdate.year = 1996
            try aenimaUpdate.update(db)

            // Tracks
            var trackIds: [Int64] = []
            let trackDefs: [(String, String, Int64, Int, Double)] = [
                ("Sweat", "/mock/opiate/01.flac", opiate.id!, 1, 226.0),
                ("Hush", "/mock/opiate/02.flac", opiate.id!, 2, 210.0),
                ("Part of Me", "/mock/opiate/03.flac", opiate.id!, 3, 198.0),
                ("Intolerance", "/mock/undertow/01.flac", undertow.id!, 1, 290.0),
                ("Prison Sex", "/mock/undertow/02.flac", undertow.id!, 2, 303.0),
                ("Sober", "/mock/undertow/03.flac", undertow.id!, 3, 316.0),
                ("Stinkfist", "/mock/aenima/01.flac", aenima.id!, 1, 316.0),
                ("Eulogy", "/mock/aenima/02.flac", aenima.id!, 2, 508.0),
                ("H.", "/mock/aenima/03.flac", aenima.id!, 3, 360.0),
            ]

            for (title, path, albumId, trackNum, duration) in trackDefs {
                var track = Track(
                    filePath: path, title: title, albumId: albumId, artistId: artistId,
                    genre: "Metal", trackNumber: trackNum, discNumber: 1,
                    duration: duration, fileSize: 50_000_000, dateAdded: Date(),
                    playCount: 0, lastPlayedAt: nil, isFavorite: false, bpm: nil)
                try track.insert(db)
                trackIds.append(track.id!)
            }

            return SeedResult(
                artistId: artistId,
                albumIds: [opiate.id!, undertow.id!, aenima.id!],
                trackIds: trackIds)
        }
    }
}
