import Foundation
import MediaPlayer

@MainActor
final class NowPlayingManager {
    private weak var playerState: PlayerState?

    init(playerState: PlayerState) {
        self.playerState = playerState
        setupRemoteCommands()
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let player = self?.playerState else { return .commandFailed }
            if !player.isPlaying { player.togglePlayPause() }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            guard let player = self?.playerState else { return .commandFailed }
            if player.isPlaying { player.togglePlayPause() }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let player = self?.playerState else { return .commandFailed }
            player.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let player = self?.playerState else { return .commandFailed }
            player.playNext()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let player = self?.playerState else { return .commandFailed }
            player.playPrevious()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let player = self?.playerState,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            player.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    func updateNowPlaying(track: TrackInfo?, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        var info = [String: Any]()

        if let track = track {
            info[MPMediaItemPropertyTitle] = track.track.title
            info[MPMediaItemPropertyArtist] = track.artist?.name ?? "Unknown Artist"
            info[MPMediaItemPropertyAlbumTitle] = track.album?.title ?? "Unknown Album"
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

            if let trackNumber = track.track.trackNumber {
                info[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = track != nil ? info : nil
    }
}
