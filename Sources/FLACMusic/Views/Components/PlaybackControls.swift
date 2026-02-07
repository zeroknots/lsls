import SwiftUI

struct PlaybackControls: View {
    @Environment(PlayerState.self) private var playerState

    var body: some View {
        HStack(spacing: 20) {
            Button {
                playerState.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(playerState.shuffleEnabled ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                playerState.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button {
                playerState.togglePlayPause()
            } label: {
                Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
            }
            .buttonStyle(.plain)

            Button {
                playerState.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button {
                playerState.cycleRepeat()
            } label: {
                Image(systemName: repeatIcon)
                    .foregroundStyle(playerState.repeatMode != .off ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var repeatIcon: String {
        switch playerState.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}
