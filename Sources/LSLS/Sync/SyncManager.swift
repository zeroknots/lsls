import AppKit
import Foundation
import GRDB

@MainActor
@Observable
final class SyncManager {
    var settings = RockboxSettings()
    var isDeviceConnected = false
    var isSyncing = false
    var syncProgress: Double = 0
    var syncStatus: String = ""
    var syncError: String?
    var lastSyncDate: Date?
    var syncItems: [SyncItem] = []

    private let db = DatabaseManager.shared
    private var pollingTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?

    init() {
        loadSettings()
        loadSyncItems()
        startPolling()
    }

    // MARK: - Settings

    func loadSettings() {
        do {
            settings = try db.dbQueue.read { db in
                try RockboxSettings.load(from: db)
            }
        } catch {
            print("Failed to load sync settings: \(error)")
        }
    }

    func saveSettings() {
        do {
            try db.dbQueue.write { db in
                try settings.save(to: db)
            }
        } catch {
            print("Failed to save sync settings: \(error)")
        }
    }

    // MARK: - Sync List Management

    func addTrack(_ trackId: Int64) {
        do {
            try db.dbQueue.write { db in
                guard try !LibraryQueries.syncItemExists(itemType: .track, trackId: trackId, in: db) else { return }
                var item = SyncItem(trackId: trackId)
                try item.insert(db)
            }
            loadSyncItems()
        } catch {
            print("Failed to add track to sync list: \(error)")
        }
    }

    func addAlbum(_ albumId: Int64) {
        do {
            try db.dbQueue.write { db in
                guard try !LibraryQueries.syncItemExists(itemType: .album, albumId: albumId, in: db) else { return }
                var item = SyncItem(albumId: albumId)
                try item.insert(db)
            }
            loadSyncItems()
        } catch {
            print("Failed to add album to sync list: \(error)")
        }
    }

    func addArtist(_ artistId: Int64) {
        do {
            try db.dbQueue.write { db in
                guard try !LibraryQueries.syncItemExists(itemType: .artist, artistId: artistId, in: db) else { return }
                var item = SyncItem(artistId: artistId)
                try item.insert(db)
            }
            loadSyncItems()
        } catch {
            print("Failed to add artist to sync list: \(error)")
        }
    }

    func removeSyncItem(_ item: SyncItem) {
        do {
            try db.dbQueue.write { db in
                _ = try item.delete(db)
            }
            loadSyncItems()
        } catch {
            print("Failed to remove sync item: \(error)")
        }
    }

    func isTrackInSyncList(_ trackId: Int64) -> Bool {
        (try? db.dbQueue.read { db in
            try LibraryQueries.syncItemExists(itemType: .track, trackId: trackId, in: db)
        }) ?? false
    }

    func isAlbumInSyncList(_ albumId: Int64) -> Bool {
        (try? db.dbQueue.read { db in
            try LibraryQueries.syncItemExists(itemType: .album, albumId: albumId, in: db)
        }) ?? false
    }

    func isArtistInSyncList(_ artistId: Int64) -> Bool {
        (try? db.dbQueue.read { db in
            try LibraryQueries.syncItemExists(itemType: .artist, artistId: artistId, in: db)
        }) ?? false
    }

    func loadSyncItems() {
        do {
            syncItems = try db.dbQueue.read { db in
                try LibraryQueries.allSyncItems(in: db)
            }
        } catch {
            print("Failed to load sync items: \(error)")
        }
    }

    // MARK: - Device Detection

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let connected = self.checkDeviceConnection()
                if connected != self.isDeviceConnected {
                    self.isDeviceConnected = connected
                    if connected && self.settings.autoSyncEnabled && !self.isSyncing && !self.syncItems.isEmpty {
                        self.startSync()
                    }
                }
                try? await Task.sleep(for: .seconds(self.settings.pollingIntervalSeconds))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func checkDeviceConnection() -> Bool {
        let path = settings.mountPath
        guard !path.isEmpty else { return false }
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: - Sync Engine

    func startSync() {
        guard !isSyncing else { return }
        guard isDeviceConnected else {
            syncError = "Device not connected"
            return
        }

        syncTask = Task { [weak self] in
            guard let self else { return }
            await self.performSync()
        }
    }

    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
        syncStatus = "Sync cancelled"
    }

    private func performSync() async {
        isSyncing = true
        syncProgress = 0
        syncStatus = "Preparing..."
        syncError = nil

        let basePath = URL(fileURLWithPath: settings.mountPath)

        do {
            // 1. Resolve all tracks to sync
            let resolvedTracks = try await db.dbQueue.read { db in
                try LibraryQueries.resolvedTracksForSync(in: db)
            }

            guard !resolvedTracks.isEmpty else {
                syncStatus = "No tracks to sync"
                isSyncing = false
                return
            }

            // 2. Load existing sync log
            let existingLogs = try await db.dbQueue.read { db in
                try LibraryQueries.allSyncLogs(in: db)
            }
            let logsByTrackId = Dictionary(uniqueKeysWithValues: existingLogs.compactMap { log -> (Int64, SyncLog)? in
                return (log.trackId, log)
            })

            let resolvedTrackIds = Set(resolvedTracks.compactMap { $0.track.id })

            // 3. Find orphaned files to remove (tracks no longer in sync list)
            let orphanedLogs = existingLogs.filter { !resolvedTrackIds.contains($0.trackId) }

            // 4. Remove orphaned files
            for log in orphanedLogs {
                let devicePath = log.devicePath
                await Task.detached(priority: .utility) {
                    let filePath = basePath.appendingPathComponent(devicePath)
                    try? FileManager.default.removeItem(at: filePath)
                }.value
                try await db.dbQueue.write { db in
                    _ = try log.delete(db)
                }
            }

            // Clean empty directories after removal
            let musicDir = basePath.appendingPathComponent("Music")
            await Task.detached(priority: .utility) {
                self.cleanEmptyDirectories(at: musicDir)
            }.value

            // 5. Determine which tracks need copying
            let tracksToSync = resolvedTracks.filter { trackInfo in
                guard let trackId = trackInfo.track.id else { return true }
                guard let log = logsByTrackId[trackId] else { return true }
                // Re-sync if file size changed
                return trackInfo.track.fileSize != log.fileSize
            }

            if tracksToSync.isEmpty {
                syncStatus = "Already up to date (\(resolvedTracks.count) tracks)"
                isSyncing = false
                lastSyncDate = Date()
                return
            }

            syncStatus = "Syncing 0/\(tracksToSync.count)..."
            var completed = 0
            var failures = 0

            // 6. Copy tracks
            for trackInfo in tracksToSync {
                if Task.isCancelled { break }

                // Verify device still connected
                guard checkDeviceConnection() else {
                    syncError = "Device disconnected during sync"
                    break
                }

                do {
                    try await syncTrack(trackInfo, to: basePath)
                    completed += 1
                } catch {
                    failures += 1
                    print("Failed to sync \(trackInfo.track.title): \(error)")
                }

                syncProgress = Double(completed + failures) / Double(tracksToSync.count)
                syncStatus = "Syncing \(completed + failures)/\(tracksToSync.count)..."
            }

            // 7. Sync artwork for all albums
            let albumIds = Set(resolvedTracks.compactMap { $0.album?.id })
            for trackInfo in resolvedTracks {
                guard let album = trackInfo.album, let albumId = album.id, albumIds.contains(albumId) else { continue }
                await syncArtwork(for: album, artistName: trackInfo.artist?.name, to: basePath)
            }

            // 8. Final status
            if failures > 0 {
                syncStatus = "Synced \(completed) tracks (\(failures) failed)"
            } else {
                syncStatus = "Synced \(completed) tracks"
            }
            lastSyncDate = Date()
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    private func syncTrack(_ trackInfo: TrackInfo, to basePath: URL) async throws {
        let sourceFile = trackInfo.track.filePath
        let ext = (sourceFile as NSString).pathExtension
        let relativePath = SyncPathBuilder.devicePath(
            artistName: trackInfo.artist?.name,
            albumTitle: trackInfo.album?.title,
            trackNumber: trackInfo.track.trackNumber,
            discNumber: trackInfo.track.discNumber,
            trackTitle: trackInfo.track.title,
            fileExtension: ext
        )
        let destURL = basePath.appendingPathComponent(relativePath)
        let fileSize = trackInfo.track.fileSize ?? 0
        let trackId = trackInfo.track.id

        // Run file I/O on background thread
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard fm.fileExists(atPath: sourceFile) else {
                throw SyncError.sourceFileNotFound(sourceFile)
            }

            let destDir = destURL.deletingLastPathComponent()
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }

            try fm.copyItem(atPath: sourceFile, toPath: destURL.path)
        }.value

        // Update sync log back on main actor
        try await db.dbQueue.write { db in
            if let trackId {
                try SyncLog
                    .filter(SyncLog.Columns.trackId == trackId)
                    .deleteAll(db)

                var log = SyncLog(
                    trackId: trackId,
                    devicePath: relativePath,
                    syncedAt: Date(),
                    fileSize: fileSize
                )
                try log.insert(db)
            }
        }
    }

    private func syncArtwork(for album: Album, artistName: String?, to basePath: URL) async {
        guard let artworkSourcePath = album.artworkPath else { return }

        let relativePath = SyncPathBuilder.artworkPath(
            artistName: artistName,
            albumTitle: album.title
        )
        let destURL = basePath.appendingPathComponent(relativePath)

        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard fm.fileExists(atPath: artworkSourcePath) else { return }
            guard !fm.fileExists(atPath: destURL.path) else { return }

            let destDir = destURL.deletingLastPathComponent()
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            try? fm.copyItem(atPath: artworkSourcePath, toPath: destURL.path)
        }.value
    }

    private nonisolated func cleanEmptyDirectories(at url: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var directories: [URL] = []
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                directories.append(fileURL)
            }
        }

        for dir in directories.sorted(by: { $0.path > $1.path }) {
            if let contents = try? fm.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }
    }
}

enum SyncError: LocalizedError {
    case sourceFileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound(let path):
            return "Source file not found: \(path)"
        }
    }
}
