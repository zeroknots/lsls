import Foundation
import GRDB

@Observable
final class DatabaseManager: Sendable {
    static let shared = DatabaseManager()

    let dbPool: DatabasePool

    private init() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDir = appSupport.appendingPathComponent("LSLS", isDirectory: true)
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbPath = dbDir.appendingPathComponent("library.sqlite").path
            dbPool = try DatabasePool(path: dbPath)
            try migrate()
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    private func migrate() throws {
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
                t.column("smartPlaylistId", .integer).notNull().references("smartPlaylist", onDelete: .cascade)
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

        migrator.registerMigration("v6") { db in
            try db.create(table: "podcast") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("author", .text)
                t.column("feedUrl", .text).notNull().unique()
                t.column("artworkUrl", .text)
                t.column("description", .text)
                t.column("lastFetchedAt", .datetime)
                t.column("dateSubscribed", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "episode") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("podcastId", .integer).notNull().references("podcast", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("audioUrl", .text).notNull()
                t.column("localFilePath", .text)
                t.column("pubDate", .datetime).notNull()
                t.column("duration", .double).notNull().defaults(to: 0)
                t.column("fileSize", .integer)
                t.column("description", .text)
                t.column("isDownloaded", .boolean).notNull().defaults(to: false)
                t.column("isPlayed", .boolean).notNull().defaults(to: false)
                t.column("playbackPosition", .double).notNull().defaults(to: 0)
                t.column("dateAdded", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.create(table: "podcastSyncItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("podcastId", .integer).notNull().references("podcast", onDelete: .cascade).unique()
                t.column("dateAdded", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }

        try migrator.migrate(dbPool)
    }
}
