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

    var currentTrack: TrackInfo?
    var isPlaying: Bool { engine.isPlaying }
    var currentTime: TimeInterval { engine.currentTime }
    var duration: TimeInterval { engine.duration }
    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    var shuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off

    init() {
        engine.onTrackFinished = { [weak self] in
            self?.playNext()
        }
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
    }

    func seekFraction(_ fraction: Double) {
        engine.seekFraction(fraction)
    }

    func addToQueue(_ track: TrackInfo) {
        queue.addNext(track)
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
        let url = URL(fileURLWithPath: track.track.filePath)
        guard FileManager.default.fileExists(atPath: track.track.filePath) else {
            playNext()
            return
        }
        currentTrack = track
        Task {
            do {
                try await engine.load(url: url)
                engine.play()
            } catch {
                print("Failed to load track: \(error)")
                playNext()
            }
        }
    }
}
