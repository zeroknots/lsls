import Foundation
import GRDB

enum EpisodeCleanupMode: String, CaseIterable, Identifiable {
    case manual
    case afterPlaying
    case afterDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .afterPlaying: return "After finishing episode"
        case .afterDays: return "After a set number of days"
        }
    }
}

@MainActor
@Observable
final class PodcastManager {
    var podcasts: [Podcast] = []
    var episodesByPodcast: [Int64: [Episode]] = [:]
    var isRefreshing = false
    var refreshStatus = ""
    var downloadingEpisodeId: Int64?
    var downloadProgress: Double = 0
    var downloadStatus = ""
    var storageDirectory: String
    var cleanupMode: EpisodeCleanupMode
    var cleanupDays: Int

    // Playback tracking
    var currentlyPlayingEpisode: Episode?
    var playerState: PlayerState?
    private var positionTimer: Timer?

    private let db = DatabaseManager.shared
    private var refreshTask: Task<Void, Never>?
    private static let refreshInterval: TimeInterval = 3600

    init() {
        if let saved = UserDefaults.standard.string(forKey: "podcastStorageDirectory"), !saved.isEmpty {
            storageDirectory = saved
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            storageDirectory = docs.appendingPathComponent("Podcasts", isDirectory: true).path
        }

        let modeRaw = UserDefaults.standard.string(forKey: "podcastCleanupMode") ?? "manual"
        cleanupMode = EpisodeCleanupMode(rawValue: modeRaw) ?? .manual
        cleanupDays = UserDefaults.standard.object(forKey: "podcastCleanupDays") as? Int ?? 14

        loadPodcasts()
        loadAllEpisodes()
        ensureStorageDirectory()
        startPeriodicRefresh()
    }

    func saveCleanupSettings() {
        UserDefaults.standard.set(cleanupMode.rawValue, forKey: "podcastCleanupMode")
        UserDefaults.standard.set(cleanupDays, forKey: "podcastCleanupDays")
    }

    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.refreshInterval))
                guard !Task.isCancelled else { break }
                await self?.refreshAllFeeds()
                await self?.cleanupOldEpisodes()
            }
        }
    }

    func saveStorageDirectory() {
        UserDefaults.standard.set(storageDirectory, forKey: "podcastStorageDirectory")
        ensureStorageDirectory()
    }

    private func ensureStorageDirectory() {
        try? FileManager.default.createDirectory(
            atPath: storageDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Search

    func search(_ query: String) async throws -> [ApplePodcastSearchResult] {
        try await PodcastSearchAPI.search(query: query)
    }

    // MARK: - Subscribe / Unsubscribe

    func subscribe(feedUrl: String, title: String? = nil, author: String? = nil, artworkUrl: String? = nil) async throws {
        let exists = try await db.dbPool.read { db in
            try Podcast.filter(Column("feedUrl") == feedUrl).fetchOne(db) != nil
        }
        guard !exists else { return }

        guard let url = URL(string: feedUrl) else {
            throw PodcastError.invalidURL
        }

        let rssFeed = try await RSSFeedParser.fetch(url: url)

        let latestEpisode: Episode? = try await db.dbPool.write { db in
            var podcast = Podcast(
                title: rssFeed.title,
                author: rssFeed.author ?? author,
                feedUrl: feedUrl,
                artworkUrl: rssFeed.artworkUrl ?? artworkUrl,
                podcastDescription: rssFeed.description,
                lastFetchedAt: Date(),
                dateSubscribed: Date()
            )
            try podcast.insert(db)

            guard let podcastId = podcast.id else { return nil }

            let sorted = rssFeed.episodes.sorted { $0.pubDate > $1.pubDate }
            var first: Episode?
            for (index, rssEpisode) in sorted.enumerated() {
                var episode = Episode(
                    podcastId: podcastId,
                    title: rssEpisode.title,
                    audioUrl: rssEpisode.audioUrl,
                    pubDate: rssEpisode.pubDate,
                    duration: rssEpisode.duration,
                    fileSize: rssEpisode.fileSize,
                    episodeDescription: rssEpisode.description,
                    isDownloaded: false,
                    isPlayed: false,
                    playbackPosition: 0,
                    dateAdded: Date()
                )
                try episode.insert(db)
                if index == 0 { first = episode }
            }
            return first
        }

        loadPodcasts()

        // Auto-download the latest episode
        if let episode = latestEpisode {
            try? await downloadEpisode(episode)
        }
    }

    func unsubscribe(_ podcast: Podcast) {
        guard let podcastId = podcast.id else { return }

        // Delete downloaded files
        do {
            let episodes = try db.dbPool.read { db in
                try Episode.filter(Column("podcastId") == podcastId).fetchAll(db)
            }
            for episode in episodes where episode.isDownloaded {
                if let path = episode.localFilePath {
                    try? FileManager.default.removeItem(atPath: path)
                }
            }
        } catch {
            print("Failed to cleanup episode files: \(error)")
        }

        do {
            try db.dbPool.write { db in
                _ = try podcast.delete(db)
            }
            loadPodcasts()
        } catch {
            print("Failed to unsubscribe: \(error)")
        }
    }

    // MARK: - Refresh

    func refreshFeed(_ podcast: Podcast) async throws {
        guard let podcastId = podcast.id else { return }

        isRefreshing = true
        refreshStatus = "Refreshing \(podcast.title)..."
        defer {
            isRefreshing = false
            refreshStatus = ""
        }

        guard let url = URL(string: podcast.feedUrl) else {
            throw PodcastError.invalidURL
        }

        let rssFeed = try await RSSFeedParser.fetch(url: url)

        // Get existing episode URLs to avoid duplicates
        let existingUrls = try await db.dbPool.read { db in
            try String.fetchAll(db, sql: "SELECT audioUrl FROM episode WHERE podcastId = ?", arguments: [podcastId])
        }
        let existingSet = Set(existingUrls)

        let latestNewEpisode: Episode? = try await db.dbPool.write { db in
            // Update podcast metadata
            try db.execute(
                sql: "UPDATE podcast SET lastFetchedAt = ?, artworkUrl = COALESCE(?, artworkUrl) WHERE id = ?",
                arguments: [Date(), rssFeed.artworkUrl, podcastId]
            )

            // Insert new episodes
            let newRssEpisodes = rssFeed.episodes
                .filter { !existingSet.contains($0.audioUrl) }
                .sorted { $0.pubDate > $1.pubDate }

            var first: Episode?
            for (index, rssEpisode) in newRssEpisodes.enumerated() {
                var episode = Episode(
                    podcastId: podcastId,
                    title: rssEpisode.title,
                    audioUrl: rssEpisode.audioUrl,
                    pubDate: rssEpisode.pubDate,
                    duration: rssEpisode.duration,
                    fileSize: rssEpisode.fileSize,
                    episodeDescription: rssEpisode.description,
                    isDownloaded: false,
                    isPlayed: false,
                    playbackPosition: 0,
                    dateAdded: Date()
                )
                try episode.insert(db)
                if index == 0 { first = episode }
            }
            return first
        }

        loadPodcasts()

        // Auto-download the latest new episode
        if let episode = latestNewEpisode {
            try? await downloadEpisode(episode)
        }
    }

    func refreshAllFeeds() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        for podcast in podcasts {
            refreshStatus = "Refreshing \(podcast.title)..."
            try? await refreshFeed(podcast)
        }
        isRefreshing = false
        refreshStatus = ""
    }

    // MARK: - Download

    var isDownloading: Bool { downloadingEpisodeId != nil }

    func downloadEpisode(_ episode: Episode) async throws {
        guard !episode.isDownloaded else { return }
        guard let episodeId = episode.id else { return }
        guard downloadingEpisodeId == nil else { return }

        downloadingEpisodeId = episodeId
        downloadProgress = 0
        downloadStatus = episode.title
        defer {
            downloadingEpisodeId = nil
            downloadProgress = 0
            downloadStatus = ""
        }

        // Try the raw URL first, then percent-encode if it fails
        guard let url = URL(string: episode.audioUrl)
                ?? URL(string: episode.audioUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            throw PodcastError.invalidURL
        }

        // Get podcast for directory name
        let podcast = try await db.dbPool.read { db in
            try Podcast.fetchOne(db, id: episode.podcastId)
        }

        let podcastDir = URL(fileURLWithPath: storageDirectory)
            .appendingPathComponent(SyncPathBuilder.sanitize(podcast?.title ?? "Unknown"))
        try FileManager.default.createDirectory(at: podcastDir, withIntermediateDirectories: true)

        let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        let filename = "\(SyncPathBuilder.sanitize(episode.title)).\(ext)"
        let destURL = podcastDir.appendingPathComponent(filename)

        // Download with progress tracking
        var request = URLRequest(url: url)
        request.timeoutInterval = 300
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        // Verify we got a successful response
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw PodcastError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        let expectedLength = response.expectedContentLength
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { try? fileHandle.close() }

        var downloadedBytes: Int64 = 0
        let bufferSize = 65_536
        var buffer = Data(capacity: bufferSize)

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= bufferSize {
                fileHandle.write(buffer)
                downloadedBytes += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if expectedLength > 0 {
                    downloadProgress = Double(downloadedBytes) / Double(expectedLength)
                }
            }
        }
        // Write remaining bytes
        if !buffer.isEmpty {
            fileHandle.write(buffer)
            downloadedBytes += Int64(buffer.count)
        }
        try fileHandle.close()

        if expectedLength > 0 {
            downloadProgress = 1.0
        }

        // Move to destination
        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.moveItem(at: tempURL, to: destURL)

        // Tag with genre="Podcasts" using ffmpeg
        downloadStatus = "Tagging..."
        await tagWithPodcastGenre(destURL)

        // Update database
        let finalSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? downloadedBytes
        let destPath = destURL.path
        try await db.dbPool.write { db in
            try db.execute(
                sql: "UPDATE episode SET isDownloaded = 1, localFilePath = ?, fileSize = ? WHERE id = ?",
                arguments: [destPath, finalSize, episodeId]
            )
        }

        reloadEpisodes(for: episode.podcastId)
    }

    private func tagWithPodcastGenre(_ url: URL) async {
        let tempURL = url.deletingLastPathComponent().appendingPathComponent("temp_tagged_\(url.lastPathComponent)")

        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
            process.arguments = [
                "-i", url.path,
                "-metadata", "genre=Podcasts",
                "-codec", "copy",
                "-y", tempURL.path
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    let fm = FileManager.default
                    try fm.removeItem(at: url)
                    try fm.moveItem(at: tempURL, to: url)
                } else {
                    try? FileManager.default.removeItem(at: tempURL)
                }
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                print("Failed to tag episode with genre: \(error)")
            }
        }.value
    }

    func deleteDownload(_ episode: Episode) {
        if let path = episode.localFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }

        do {
            try db.dbPool.write { db in
                guard let episodeId = episode.id else { return }
                try db.execute(
                    sql: "UPDATE episode SET isDownloaded = 0, localFilePath = NULL WHERE id = ?",
                    arguments: [episodeId]
                )
            }
            reloadEpisodes(for: episode.podcastId)
        } catch {
            print("Failed to update episode: \(error)")
        }
    }

    // MARK: - Playback

    func playEpisode(_ episode: Episode, podcast: Podcast) {
        guard let player = playerState else { return }

        let filePath = episode.localFilePath ?? episode.audioUrl

        let track = Track(
            id: nil,
            filePath: filePath,
            title: episode.title,
            albumId: nil,
            artistId: nil,
            genre: "Podcasts",
            trackNumber: nil,
            discNumber: nil,
            duration: episode.duration,
            fileSize: episode.fileSize,
            dateAdded: episode.dateAdded,
            playCount: 0,
            lastPlayedAt: nil,
            isFavorite: false,
            bpm: nil
        )

        let artist = Artist(id: nil, name: podcast.title)
        let trackInfo = TrackInfo(track: track, album: nil, artist: artist)

        currentlyPlayingEpisode = episode
        player.play(track: trackInfo)
        startPositionTracking()
    }

    private func startPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveCurrentPosition()
            }
        }
    }

    private func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func saveCurrentPosition() {
        guard let episode = currentlyPlayingEpisode,
              let player = playerState else {
            stopPositionTracking()
            return
        }

        // Detect if the podcast episode is no longer playing
        if player.currentTrack == nil || player.currentTrack?.track.title != episode.title {
            let wasPlaying = currentlyPlayingEpisode
            currentlyPlayingEpisode = nil
            stopPositionTracking()
            if let ep = wasPlaying {
                onEpisodeFinished(ep)
            }
            return
        }

        // Save position
        let position = player.currentTime
        guard let episodeId = episode.id, position > 0 else { return }
        do {
            try db.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE episode SET playbackPosition = ? WHERE id = ?",
                    arguments: [position, episodeId]
                )
            }
        } catch {
            print("Failed to save playback position: \(error)")
        }
    }

    private func onEpisodeFinished(_ episode: Episode) {
        markPlayed(episode)
        if cleanupMode == .afterPlaying && episode.isDownloaded {
            deleteDownload(episode)
        }
    }

    // MARK: - Playback Tracking

    func markPlayed(_ episode: Episode) {
        guard let episodeId = episode.id else { return }
        do {
            try db.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE episode SET isPlayed = 1 WHERE id = ?",
                    arguments: [episodeId]
                )
            }
            reloadEpisodes(for: episode.podcastId)
        } catch {
            print("Failed to mark episode played: \(error)")
        }
    }

    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) {
        guard let episodeId = episode.id else { return }
        do {
            try db.dbPool.write { db in
                try db.execute(
                    sql: "UPDATE episode SET playbackPosition = ? WHERE id = ?",
                    arguments: [position, episodeId]
                )
            }
            reloadEpisodes(for: episode.podcastId)
        } catch {
            print("Failed to update playback position: \(error)")
        }
    }

    // MARK: - Cleanup

    func cleanupOldEpisodes() {
        guard cleanupMode == .afterDays, cleanupDays > 0 else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -cleanupDays, to: Date()) ?? Date()

        do {
            let downloadedEpisodes = try db.dbPool.read { db in
                try Episode
                    .filter(Column("isDownloaded") == true)
                    .filter(Column("dateAdded") < cutoffDate)
                    .fetchAll(db)
            }

            for episode in downloadedEpisodes {
                deleteDownload(episode)
            }
        } catch {
            print("Failed to cleanup old episodes: \(error)")
        }
    }

    // MARK: - Sync List

    func isPodcastInSyncList(_ podcastId: Int64) -> Bool {
        (try? db.dbPool.read { db in
            try PodcastSyncItem.filter(Column("podcastId") == podcastId).fetchOne(db) != nil
        }) ?? false
    }

    func addPodcastToSyncList(_ podcastId: Int64) {
        do {
            try db.dbPool.write { db in
                guard try PodcastSyncItem.filter(Column("podcastId") == podcastId).fetchOne(db) == nil else { return }
                var item = PodcastSyncItem(podcastId: podcastId)
                try item.insert(db)
            }
        } catch {
            print("Failed to add podcast to sync list: \(error)")
        }
    }

    func removePodcastFromSyncList(_ podcastId: Int64) {
        do {
            _ = try db.dbPool.write { db in
                try PodcastSyncItem.filter(Column("podcastId") == podcastId).deleteAll(db)
            }
        } catch {
            print("Failed to remove podcast from sync list: \(error)")
        }
    }

    // MARK: - Loading

    func loadPodcasts() {
        do {
            podcasts = try db.dbPool.read { db in
                try Podcast.order(Column("title")).fetchAll(db)
            }
            loadAllEpisodes()
        } catch {
            print("Failed to load podcasts: \(error)")
        }
    }

    private func loadAllEpisodes() {
        do {
            let allEpisodes = try db.dbPool.read { db in
                try Episode.order(Column("pubDate").desc).fetchAll(db)
            }
            var grouped: [Int64: [Episode]] = [:]
            for episode in allEpisodes {
                grouped[episode.podcastId, default: []].append(episode)
            }
            episodesByPodcast = grouped
        } catch {
            print("Failed to load episodes: \(error)")
        }
    }

    private func reloadEpisodes(for podcastId: Int64) {
        do {
            episodesByPodcast[podcastId] = try db.dbPool.read { db in
                try Episode
                    .filter(Column("podcastId") == podcastId)
                    .order(Column("pubDate").desc)
                    .fetchAll(db)
            }
        } catch {
            print("Failed to reload episodes: \(error)")
        }
    }

    func episodesForPodcast(_ podcastId: Int64) -> [Episode] {
        episodesByPodcast[podcastId] ?? []
    }

    func downloadedEpisodesForSync() throws -> [EpisodeInfo] {
        try db.dbPool.read { db in
            let request = Episode
                .filter(Column("isDownloaded") == true)
                .joining(required: Episode.podcast.joining(
                    required: Podcast.hasOne(PodcastSyncItem.self)
                ))
                .including(optional: Episode.podcast)
                .order(Column("pubDate").desc)
            return try EpisodeInfo.fetchAll(db, request)
        }
    }
}
