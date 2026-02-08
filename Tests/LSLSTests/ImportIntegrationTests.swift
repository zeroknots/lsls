import Foundation
import GRDB
import Testing

@testable import LSLS

@Suite("Import Integration")
struct ImportIntegrationTests {

    // MARK: - Metadata reading from generated FLAC

    @Test("read metadata from generated FLAC file")
    func readMetadataFromFixture() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(
            in: tmpDir,
            title: "Stinkfist",
            artist: "TOOL",
            album: "Ænima",
            year: "1996",
            track: "1/13",
            genre: "Metal"
        )

        let metadata = try await MetadataReader.read(from: flac)
        #expect(metadata.title == "Stinkfist")
        #expect(metadata.artist == "TOOL")
        #expect(metadata.albumTitle == "Ænima")
        #expect(metadata.year == 1996)
        #expect(metadata.trackNumber == 1)
        #expect(metadata.genre == "Metal")
        #expect(metadata.duration > 0)
        #expect(metadata.fileSize > 0)
    }

    // MARK: - Artwork extraction from generated FLAC

    @Test("extract artwork from generated FLAC with embedded art")
    func extractArtworkFromFixture() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(
            in: tmpDir,
            withArtwork: true
        )

        let data = await MetadataReader.extractArtwork(from: flac)
        #expect(data != nil)
        guard let data else { return }
        #expect(data.count > 100, "Artwork should be non-trivial size")
        // JPEG starts with FF D8
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xD8)
    }

    @Test("no artwork from generated FLAC without embedded art")
    func noArtworkFromPlainFixture() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(
            in: tmpDir,
            withArtwork: false
        )

        let data = await MetadataReader.extractArtwork(from: flac)
        #expect(data == nil)
    }

    // MARK: - Database operations with test DB

    @Test("insert and query artist/album/track in test database")
    func databaseInsertAndQuery() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)

        try dbPool.write { db in
            let artist = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            #expect(artist.id != nil)
            #expect(artist.name == "TOOL")

            let album = try LibraryQueries.findOrCreateAlbum(
                title: "Opiate", artistId: artist.id, in: db)
            #expect(album.id != nil)
            #expect(album.title == "Opiate")
            #expect(album.artistId == artist.id)

            var track = Track(
                filePath: "/test/01.flac", title: "Sweat",
                albumId: album.id, artistId: artist.id,
                genre: "Metal", trackNumber: 1, discNumber: 1,
                duration: 226.0, fileSize: 50_000_000,
                dateAdded: Date(), playCount: 0, isFavorite: false)
            try track.insert(db)
            #expect(track.id != nil)

            let fetched = try Track.fetchOne(db, key: track.id!)
            #expect(fetched?.title == "Sweat")
            #expect(fetched?.albumId == album.id)
            #expect(fetched?.artistId == artist.id)
        }
    }

    @Test("findOrCreateArtist is idempotent")
    func findOrCreateArtistIdempotent() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)

        try dbPool.write { db in
            let first = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            let second = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            #expect(first.id == second.id)

            let count = try Artist.fetchCount(db)
            #expect(count == 1)
        }
    }

    @Test("findOrCreateAlbum is idempotent")
    func findOrCreateAlbumIdempotent() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)

        try dbPool.write { db in
            let artist = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            let first = try LibraryQueries.findOrCreateAlbum(
                title: "Opiate", artistId: artist.id, in: db)
            let second = try LibraryQueries.findOrCreateAlbum(
                title: "Opiate", artistId: artist.id, in: db)
            #expect(first.id == second.id)

            let count = try Album.fetchCount(db)
            #expect(count == 1)
        }
    }

    @Test("seed mock data creates correct structure")
    func seedMockData() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)
        let seed = try TestFixtures.seedMockData(in: dbPool)

        try dbPool.read { db in
            let artistCount = try Artist.fetchCount(db)
            let albumCount = try Album.fetchCount(db)
            let trackCount = try Track.fetchCount(db)

            #expect(artistCount == 1)
            #expect(albumCount == 3)
            #expect(trackCount == 9)
            #expect(seed.albumIds.count == 3)
            #expect(seed.trackIds.count == 9)

            // Verify album years
            let opiate = try Album.fetchOne(db, key: seed.albumIds[0])
            #expect(opiate?.year == 1992)

            // Verify track belongs to album
            let sweat = try Track.filter(Track.Columns.title == "Sweat").fetchOne(db)
            #expect(sweat?.albumId == seed.albumIds[0])
            #expect(sweat?.artistId == seed.artistId)
        }
    }

    @Test("albums without artwork are found by missing artwork query")
    func albumsMissingArtwork() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)
        let seed = try TestFixtures.seedMockData(in: dbPool)

        // All albums start with nil artworkPath
        let albumsNeedingArtwork: [(albumId: Int64, trackPath: String)] = try dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.id, t.filePath
                FROM album a
                JOIN track t ON t.albumId = a.id
                WHERE a.artworkPath IS NULL
                GROUP BY a.id
                """)
            return rows.map { (albumId: $0["id"] as Int64, trackPath: $0["filePath"] as String) }
        }

        #expect(albumsNeedingArtwork.count == 3)

        // Set artwork on one album
        try dbPool.write { db in
            if var album = try Album.fetchOne(db, key: seed.albumIds[0]) {
                album.artworkPath = "/fake/artwork.jpg"
                try album.update(db)
            }
        }

        let remaining: Int = try dbPool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM album WHERE artworkPath IS NULL")!
        }
        #expect(remaining == 2)
    }

    @Test("multiple tracks import to same album")
    func multipleTracksShareAlbum() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)

        try dbPool.write { db in
            let artist = try LibraryQueries.findOrCreateArtist(name: "TOOL", in: db)
            let album = try LibraryQueries.findOrCreateAlbum(
                title: "Opiate", artistId: artist.id, in: db)

            for i in 1...6 {
                var track = Track(
                    filePath: "/test/opiate/\(String(format: "%02d", i)).flac",
                    title: "Track \(i)",
                    albumId: album.id, artistId: artist.id,
                    trackNumber: i, discNumber: 1,
                    duration: Double(200 + i * 10), fileSize: 40_000_000,
                    dateAdded: Date(), playCount: 0, isFavorite: false)
                try track.insert(db)
            }

            let tracks = try Track.filter(Track.Columns.albumId == album.id).fetchAll(db)
            #expect(tracks.count == 6)

            // All share one album, one artist
            #expect(try Album.fetchCount(db) == 1)
            #expect(try Artist.fetchCount(db) == 1)
        }
    }

    @Test("LibraryQueries.search finds tracks by title")
    func searchByTitle() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)
        _ = try TestFixtures.seedMockData(in: dbPool)

        try dbPool.read { db in
            let results = try LibraryQueries.search("Stinkfist", in: db)
            #expect(results.tracks.count == 1)
            #expect(results.tracks.first?.track.title == "Stinkfist")
        }
    }

    @Test("deleteOrphans removes albums and artists with no tracks")
    func deleteOrphans() throws {
        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let dbPool = try TestFixtures.createTestDatabase(in: tmpDir)
        let seed = try TestFixtures.seedMockData(in: dbPool)

        // Delete all tracks for Opiate album
        try dbPool.write { db in
            try Track.filter(Track.Columns.albumId == seed.albumIds[0]).deleteAll(db)
            try LibraryQueries.deleteOrphans(in: db)

            // Opiate album should be gone
            #expect(try Album.fetchCount(db) == 2)
            #expect(try Artist.fetchCount(db) == 1) // TOOL still has other tracks
        }
    }
}
