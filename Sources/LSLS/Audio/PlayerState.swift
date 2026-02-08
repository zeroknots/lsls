import Foundation
import SwiftUI

enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one
}

@MainActor
@Observable
final class PlayerState {
    let engine = AudioEngine()
    let queue = PlayQueue()
    private var nowPlayingManager: NowPlayingManager?
    private var nowPlayingTimer: Timer?

    var currentTrack: TrackInfo?
    var currentFormat: AudioFormat?
    var isPlaying: Bool { engine.isPlaying }
    var currentTime: TimeInterval { engine.currentTime }
    var duration: TimeInterval { engine.duration }
    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    var shuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off
    var isQueueVisible: Bool = false

    init() {
        engine.onTrackFinished = { [weak self] in
            self?.recordPlay()
            self?.playNext()
        }
        nowPlayingManager = NowPlayingManager(playerState: self)
    }

    func play(track: TrackInfo, fromQueue: [TrackInfo]? = nil) {
        if let tracks = fromQueue {
            queue.setQueue(tracks, startingAt: track)
        } else {
            queue.setQueue([track], startingAt: track)
        }
        loadAndPlay(track)
    }

    func togglePlayPause() {
        engine.togglePlayPause()
        updateNowPlaying()
    }

    func playNext() {
        if repeatMode == .one, let current = currentTrack {
            loadAndPlay(current)
            return
        }
        guard let next = queue.next(shuffle: shuffleEnabled) else {
            if repeatMode == .all {
                queue.restart()
                if let first = queue.current {
                    loadAndPlay(first)
                }
            } else {
                engine.stop()
                currentTrack = nil
                currentFormat = nil
                nowPlayingTimer?.invalidate()
                updateNowPlaying()
            }
            return
        }
        loadAndPlay(next)
    }

    func playPrevious() {
        if engine.currentTime > 3 {
            engine.seek(to: 0)
            return
        }
        guard let prev = queue.previous() else { return }
        loadAndPlay(prev)
    }

    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        updateNowPlaying()
    }

    func seekFraction(_ fraction: Double) {
        engine.seekFraction(fraction)
    }

    func addToQueue(_ track: TrackInfo) {
        queue.addNext(track)
    }

    func addToQueueEnd(_ track: TrackInfo) {
        queue.appendToEnd(track)
    }

    func addAlbumToQueue(_ albumId: Int64) {
        let db = DatabaseManager.shared
        Task {
            do {
                let tracks = try await db.dbPool.read { db in
                    try LibraryQueries.tracksForAlbum(albumId, in: db)
                }
                for track in tracks {
                    queue.appendToEnd(track)
                }
            } catch {
                print("Failed to load album tracks for queue: \(error)")
            }
        }
    }

    func addArtistToQueue(_ artistId: Int64) {
        let db = DatabaseManager.shared
        Task {
            do {
                let tracks = try await db.dbPool.read { db in
                    try LibraryQueries.tracksForArtist(artistId, in: db)
                }
                for track in tracks {
                    queue.appendToEnd(track)
                }
            } catch {
                print("Failed to load artist tracks for queue: \(error)")
            }
        }
    }

    func moveInQueue(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }

    func removeFromQueue(at upNextIndex: Int) {
        queue.removeFromUpNext(at: upNextIndex)
    }

    func toggleShuffle() {
        shuffleEnabled.toggle()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func loadAndPlay(_ track: TrackInfo) {
        let url: URL
        if track.track.filePath.hasPrefix("http") {
            guard let streamURL = URL(string: track.track.filePath) else {
                playNext()
                return
            }
            url = streamURL
        } else {
            url = URL(fileURLWithPath: track.track.filePath)
            guard FileManager.default.fileExists(atPath: track.track.filePath) else {
                playNext()
                return
            }
        }
        currentTrack = track
        currentFormat = nil
        Task {
            do {
                try await engine.load(url: url)
                engine.play()
                updateNowPlaying()
                startNowPlayingTimer()

                let format = await MetadataReader.readAudioFormat(from: url)
                self.currentFormat = format
            } catch {
                print("Failed to load track: \(error)")
                playNext()
            }
        }
    }

    private func updateNowPlaying() {
        nowPlayingManager?.updateNowPlaying(
            track: currentTrack,
            isPlaying: engine.isPlaying,
            currentTime: engine.currentTime,
            duration: engine.duration
        )
    }

    private func startNowPlayingTimer() {
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateNowPlaying()
            }
        }
    }

    private func recordPlay() {
        guard let trackId = currentTrack?.track.id else { return }
        let db = DatabaseManager.shared
        Task.detached(priority: .utility) {
            try? await db.dbPool.write { dbConn in
                try LibraryQueries.recordPlay(trackId: trackId, in: dbConn)
            }
        }
    }
}
