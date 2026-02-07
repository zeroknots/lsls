@preconcurrency import AVFoundation
import Foundation

@MainActor
@Observable
final class AudioEngine {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 0.75 {
        didSet { player?.volume = volume }
    }

    var onTrackFinished: (() -> Void)?

    func load(url: URL) async throws {
        stop()

        let item = AVPlayerItem(url: url)
        let dur = try await item.asset.load(.duration)
        duration = dur.seconds.isFinite ? dur.seconds : 0

        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = volume

        playerItem = item
        player = avPlayer
        currentTime = 0

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
                self?.stopProgressUpdates()
                self?.onTrackFinished?()
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        startProgressUpdates()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressUpdates()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func seekFraction(_ fraction: Double) {
        seek(to: duration * fraction)
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }
    }

    private func stopProgressUpdates() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}
