import Foundation
import GRDB
import Testing

@testable import LSLS

@Suite("Import Integration")
struct ImportIntegrationTests {

    private static let toolFolder = URL(
        fileURLWithPath:
            "/Volumes/media/music/TOOL DISCOGRAPHY [24 96] REMASTERED - QOBUZ - MMXX")

    private static func requireToolFolder() throws -> URL {
        try #require(
            FileManager.default.fileExists(atPath: toolFolder.path),
            "TOOL discography folder not mounted at \(toolFolder.path)"
        )
        return toolFolder
    }

    @Test("scan finds all FLAC files in TOOL discography")
    func scanFiles() throws {
        let folder = try Self.requireToolFolder()

        var audioFiles: [URL] = []
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ))

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if MetadataReader.supportedExtensions.contains(ext) {
                audioFiles.append(fileURL)
            }
        }

        print("Found \(audioFiles.count) audio files")
        #expect(audioFiles.count > 50)
    }

    @Test("read metadata from multiple TOOL albums")
    func readMultipleFiles() async throws {
        let folder = try Self.requireToolFolder()

        let testFiles = [
            folder.appendingPathComponent(
                "TOOL [24 96] MMXX/[1992] OPIATE EP/01 - Sweat.flac"),
            folder.appendingPathComponent(
                "TOOL [24 96] MMXX/[1993] UNDERTOW/01 - Intolerance.flac"),
            folder.appendingPathComponent(
                "TOOL [24 96] MMXX/[1996] ÆNIMA/01 - Stinkfist.flac"),
        ]

        for file in testFiles {
            try #require(
                FileManager.default.fileExists(atPath: file.path),
                "Missing test file: \(file.lastPathComponent)"
            )

            let metadata = try await MetadataReader.read(from: file)
            print(
                "  \(file.lastPathComponent): title=\(metadata.title), artist=\(metadata.artist ?? "nil"), album=\(metadata.albumTitle ?? "nil")"
            )

            #expect(metadata.artist == "TOOL")
            #expect(metadata.albumTitle != nil)
            #expect(!metadata.albumTitle!.isEmpty)
            #expect(metadata.duration > 0)
        }
    }

    @Test("full import pipeline using production LibraryManager.importFile")
    @MainActor
    func fullImportPipeline() async throws {
        let folder = try Self.requireToolFolder()

        // Scan for files
        var audioFiles: [URL] = []
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ))
        for case let fileURL as URL in enumerator {
            if MetadataReader.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                audioFiles.append(fileURL)
            }
        }
        audioFiles.sort { $0.path < $1.path }
        print("Importing \(audioFiles.count) files via LibraryManager.importFile...")

        // Use the REAL production LibraryManager + DatabaseManager.shared
        let manager = LibraryManager()
        let db = DatabaseManager.shared

        // Clear any existing data first
        try await db.dbPool.write { dbConn in
            try Track.deleteAll(dbConn)
            try Album.deleteAll(dbConn)
            try Artist.deleteAll(dbConn)
        }

        // Import each file using the actual production code path
        for fileURL in audioFiles {
            await manager.importFile(fileURL)
        }

        // Verify results from the real database
        let expectedCount = audioFiles.count
        try await db.dbPool.read { dbConn in
            let trackCount = try Track.fetchCount(dbConn)
            let albumCount = try Album.fetchCount(dbConn)
            let artistCount = try Artist.fetchCount(dbConn)

            print("Results: \(trackCount) tracks, \(albumCount) albums, \(artistCount) artists")

            #expect(trackCount == expectedCount)
            #expect(albumCount >= 6)
            #expect(artistCount >= 1)

            // Check a specific track has proper associations
            let track = try Track.filter(Column("title") == "Sweat").fetchOne(dbConn)
            #expect(track != nil)
            #expect(track?.albumId != nil)
            #expect(track?.artistId != nil)

            if let albumId = track?.albumId {
                let album = try Album.fetchOne(dbConn, id: albumId)
                #expect(album?.title == "Opiate")
                #expect(album?.year == 1992)
            }

            if let artistId = track?.artistId {
                let artist = try Artist.fetchOne(dbConn, id: artistId)
                #expect(artist?.name == "TOOL")
            }

            // Every track must have artist and album
            let tracksWithoutArtist = try Track.filter(Column("artistId") == nil).fetchCount(dbConn)
            let tracksWithoutAlbum = try Track.filter(Column("albumId") == nil).fetchCount(dbConn)
            print("Tracks without artist: \(tracksWithoutArtist)")
            print("Tracks without album: \(tracksWithoutAlbum)")
            #expect(tracksWithoutArtist == 0)
            #expect(tracksWithoutAlbum == 0)
        }

        // Clean up test data
        try await db.dbPool.write { dbConn in
            try Track.deleteAll(dbConn)
            try Album.deleteAll(dbConn)
            try Artist.deleteAll(dbConn)
        }
    }
}
