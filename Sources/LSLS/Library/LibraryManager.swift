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
        let existingPaths: Set<String> = (try? await db.dbPool.read { dbConn in
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
        let batchSize = 8
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

        importStatus = "Scanning for missing artwork..."
        await scanMissingArtwork(folderURL: folderURL)

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

    nonisolated private static let coverArtFilenames: Set<String> = [
        "cover.jpg", "cover.jpeg", "cover.png",
        "folder.jpg", "folder.jpeg", "folder.png",
        "front.jpg", "front.jpeg", "front.png",
        "album.jpg", "album.jpeg", "album.png",
        "art.jpg", "art.jpeg", "art.png",
    ]

    nonisolated static func findFolderArtworkData(for fileURL: URL) -> Data? {
        let folder = fileURL.deletingLastPathComponent()
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: folder.path) else { return nil }

        for filename in contents {
            if coverArtFilenames.contains(filename.lowercased()) {
                let artPath = folder.appendingPathComponent(filename).path
                if let data = try? Data(contentsOf: URL(fileURLWithPath: artPath)) {
                    return data
                }
            }
        }
        return nil
    }

    nonisolated func importFile(_ fileURL: URL) async {
        let db = DatabaseManager.shared

        do {
            let metadata = try await MetadataReader.read(from: fileURL)

            // Check if album needs artwork — off main thread
            let needsArtwork = try await db.dbPool.read { dbConn -> Bool in
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
                return true
            }

            // Find/extract artwork data — off main thread
            let artworkData: Data?
            if needsArtwork {
                if let folderArt = Self.findFolderArtworkData(for: fileURL) {
                    artworkData = folderArt
                } else {
                    artworkData = await MetadataReader.extractArtwork(from: fileURL)
                }
            } else {
                artworkData = nil
            }
            let hasArtwork = artworkData != nil

            // Write track to DB — off main thread
            let albumIdNeedingArtwork: Int64? = try await db.dbPool.write { dbConn in
                if try Track.filter(Track.Columns.filePath == fileURL.path).fetchOne(dbConn) != nil {
                    return nil
                }

                var artistId: Int64?
                if let artistName = metadata.artist, !artistName.isEmpty {
                    let artist = try LibraryQueries.findOrCreateArtist(name: artistName, in: dbConn)
                    artistId = artist.id
                }

                var albumId: Int64?
                if let albumTitle = metadata.albumTitle, !albumTitle.isEmpty {
                    let album = try LibraryQueries.findOrCreateAlbum(title: albumTitle, artistId: artistId, in: dbConn)
                    albumId = album.id

                    if album.year == nil, let year = metadata.year {
                        var updatedAlbum = album
                        updatedAlbum.year = year
                        try updatedAlbum.update(dbConn)
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
                    isFavorite: false,
                    bpm: metadata.bpm
                )
                try track.insert(dbConn)

                if let aId = albumId, hasArtwork {
                    let album = try Album.fetchOne(dbConn, key: aId)
                    if album?.artworkPath == nil { return aId }
                }
                return nil
            }

            // Save artwork — only this needs MainActor (for ArtworkCache)
            if let artworkData, let albumId = albumIdNeedingArtwork {
                let savedPath = await MainActor.run {
                    NSImage(data: artworkData).flatMap {
                        ArtworkCache.shared.saveArtwork($0, for: albumId)
                    }
                }
                if let savedPath {
                    try? await db.dbPool.write { dbConn in
                        if var album = try Album.fetchOne(dbConn, key: albumId) {
                            album.artworkPath = savedPath
                            try album.update(dbConn)
                        }
                    }
                }
            }
        } catch {
            print("Failed to import \(fileURL.lastPathComponent): \(error)")
        }
    }

    func scanMissingArtwork(folderURL: URL? = nil) async {
        isImporting = true
        importStatus = "Scanning for missing artwork..."

        let db = DatabaseManager.shared

        let albumsNeedingArtwork: [(albumId: Int64, trackPath: String)] = (try? await db.dbPool.read { dbConn in
            let rows = try Row.fetchAll(dbConn, sql: """
                SELECT a.id, t.filePath
                FROM album a
                JOIN track t ON t.albumId = a.id
                WHERE a.artworkPath IS NULL
                GROUP BY a.id
                """)
            return rows.map { (albumId: $0["id"] as Int64, trackPath: $0["filePath"] as String) }
        }) ?? []

        guard !albumsNeedingArtwork.isEmpty else {
            importStatus = "All albums have artwork"
            isImporting = false
            return
        }

        let total = albumsNeedingArtwork.count
        var found = 0

        for (index, item) in albumsNeedingArtwork.enumerated() {
            importStatus = "Extracting artwork \(index + 1)/\(total)..."
            let fileURL = URL(fileURLWithPath: item.trackPath)

            print("scanMissingArtwork: [\(index + 1)/\(total)] extracting from \(fileURL.lastPathComponent)...")
            let start = Date()

            guard let artworkData = await MetadataReader.extractArtwork(from: fileURL) else {
                print("scanMissingArtwork: FAILED - no data for album \(item.albumId)")
                continue
            }

            let elapsed = Date().timeIntervalSince(start)
            print("scanMissingArtwork: got \(artworkData.count) bytes in \(String(format: "%.1f", elapsed))s")

            guard let image = NSImage(data: artworkData),
                  let savedPath = ArtworkCache.shared.saveArtwork(image, for: item.albumId) else {
                print("scanMissingArtwork: FAILED to save image for album \(item.albumId)")
                continue
            }

            try? await db.dbPool.write { dbConn in
                if var album = try Album.fetchOne(dbConn, key: item.albumId) {
                    album.artworkPath = savedPath
                    try album.update(dbConn)
                }
            }

            ArtworkCache.shared.clearMemoryCache()
            found += 1
            print("scanMissingArtwork: SUCCESS album \(item.albumId) -> \(savedPath)")
        }

        importStatus = found > 0 ? "Found artwork for \(found) album\(found == 1 ? "" : "s")" : "No artwork found"
        isImporting = false
    }

    nonisolated static func analyzeBPM(for track: Track) async {
        guard let trackId = track.id, !track.filePath.hasPrefix("http") else { return }
        let url = URL(fileURLWithPath: track.filePath)

        let bpm: Double?
        if let metadata = try? await MetadataReader.read(from: url), let tagBPM = metadata.bpm {
            bpm = tagBPM
        } else {
            bpm = await MetadataReader.detectBPMWithAubio(from: url)
        }

        guard let bpm else { return }
        try? await DatabaseManager.shared.dbPool.write { dbConn in
            try dbConn.execute(
                sql: "UPDATE track SET bpm = ? WHERE id = ?",
                arguments: [bpm, trackId]
            )
        }
    }
}
