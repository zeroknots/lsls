import AppKit
import Foundation
import GRDB

@MainActor
@Observable
final class LibraryManager {
    var isImporting = false
    var importProgress: Double = 0
    var importStatus: String = ""
    var lastImportDate: Date?

    private let db = DatabaseManager.shared

    func importFolder(_ folderURL: URL) async {
        let gotAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if gotAccess { folderURL.stopAccessingSecurityScopedResource() } }

        isImporting = true
        importProgress = 0
        importStatus = "Scanning..."

        let files = scanForAudioFiles(in: folderURL)
        guard !files.isEmpty else {
            importStatus = "No audio files found"
            isImporting = false
            return
        }

        // Filter out already-imported files before doing expensive ffprobe work
        let existingPaths: Set<String> = (try? await db.dbQueue.read { dbConn in
            let paths = try String.fetchAll(dbConn, Track.select(Track.Columns.filePath))
            return Set(paths)
        }) ?? []
        let newFiles = files.filter { !existingPaths.contains($0.path) }

        guard !newFiles.isEmpty else {
            importStatus = "All \(files.count) files already imported"
            isImporting = false
            return
        }

        importStatus = "Importing \(newFiles.count) files..."
        let total = newFiles.count
        var completed = 0

        // Process in batches for concurrency without data race issues
        let batchSize = 4
        for batchStart in stride(from: 0, to: newFiles.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, newFiles.count)
            let batch = Array(newFiles[batchStart..<batchEnd])

            await withTaskGroup(of: Void.self) { group in
                for fileURL in batch {
                    group.addTask {
                        await self.importFile(fileURL)
                    }
                }
            }

            completed += batch.count
            importProgress = Double(completed) / Double(total)
            importStatus = "Importing \(completed)/\(total)..."
        }

        importStatus = "Imported \(total) files"
        isImporting = false
        lastImportDate = Date()
    }

    private func scanForAudioFiles(in url: URL) -> [URL] {
        var audioFiles: [URL] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if MetadataReader.supportedExtensions.contains(ext) {
                audioFiles.append(fileURL)
            }
        }

        return audioFiles.sorted { $0.path < $1.path }
    }

    private static let coverArtFilenames: Set<String> = [
        "cover.jpg", "cover.jpeg", "cover.png",
        "folder.jpg", "folder.jpeg", "folder.png",
        "front.jpg", "front.jpeg", "front.png",
        "album.jpg", "album.jpeg", "album.png",
        "art.jpg", "art.jpeg", "art.png",
    ]

    private func findFolderArtwork(for fileURL: URL) -> NSImage? {
        let folder = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: folder.path) else { return nil }

        for filename in contents {
            if Self.coverArtFilenames.contains(filename.lowercased()) {
                let artPath = folder.appendingPathComponent(filename).path
                if let image = NSImage(contentsOfFile: artPath) {
                    return image
                }
            }
        }
        return nil
    }

    nonisolated func importFile(_ fileURL: URL) async {
        do {
            let metadata = try await MetadataReader.read(from: fileURL)

            // Check if album needs artwork before doing expensive extraction
            let needsArtwork = try await MainActor.run {
                try db.dbQueue.read { dbConn -> Bool in
                    guard let albumTitle = metadata.albumTitle, !albumTitle.isEmpty else { return false }
                    var query = Album.filter(Album.Columns.title == albumTitle)
                    if let artistName = metadata.artist, !artistName.isEmpty,
                       let artist = try Artist.filter(Artist.Columns.name == artistName).fetchOne(dbConn)
                    {
                        query = query.filter(Album.Columns.artistId == artist.id)
                    }
                    if let album = try query.fetchOne(dbConn) {
                        return album.artworkPath == nil
                    }
                    return true // new album, will need artwork
                }
            }

            var embeddedArtworkData: Data?
            if needsArtwork {
                embeddedArtworkData = await MetadataReader.extractArtwork(from: fileURL)
            }

            try await MainActor.run {
                try db.dbQueue.write { dbConn in
                    if try Track.filter(Track.Columns.filePath == fileURL.path).fetchOne(dbConn) != nil {
                        return
                    }

                    var artistId: Int64?
                    if let artistName = metadata.artist, !artistName.isEmpty {
                        let artist = try LibraryQueries.findOrCreateArtist(name: artistName, in: dbConn)
                        artistId = artist.id
                    }

                    var albumId: Int64?
                    if let albumTitle = metadata.albumTitle, !albumTitle.isEmpty {
                        var album = try LibraryQueries.findOrCreateAlbum(title: albumTitle, artistId: artistId, in: dbConn)
                        albumId = album.id

                        if album.artworkPath == nil, let aId = albumId {
                            let artworkImage = findFolderArtwork(for: fileURL)
                                ?? embeddedArtworkData.flatMap { NSImage(data: $0) }
                            if let artwork = artworkImage,
                               let savedPath = ArtworkCache.shared.saveArtwork(artwork, for: aId)
                            {
                                album.artworkPath = savedPath
                                try album.update(dbConn)
                            }
                        }

                        if album.year == nil, let year = metadata.year {
                            album.year = year
                            try album.update(dbConn)
                        }
                    }

                    var track = Track(
                        filePath: fileURL.path,
                        title: metadata.title,
                        albumId: albumId,
                        artistId: artistId,
                        genre: metadata.genre,
                        trackNumber: metadata.trackNumber,
                        discNumber: metadata.discNumber ?? 1,
                        duration: metadata.duration,
                        fileSize: metadata.fileSize,
                        dateAdded: Date(),
                        playCount: 0,
                        lastPlayedAt: nil,
                        isFavorite: false
                    )
                    try track.insert(dbConn)
                }
            }
        } catch {
            print("Failed to import \(fileURL.lastPathComponent): \(error)")
        }
    }
}
