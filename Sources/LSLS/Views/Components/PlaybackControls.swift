import SwiftUI

struct PlaybackControls: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors

    var body: some View {
        HStack(spacing: 24) {
            // Shuffle
            VStack(spacing: 2) {
                Button {
                    playerState.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(playerState.shuffleEnabled ? colors.accent : colors.textTertiary)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(playerState.shuffleEnabled ? colors.accent : .clear)
                    .frame(width: 4, height: 4)
            }

            Button {
                playerState.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            Button {
                playerState.togglePlayPause()
            } label: {
                Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            Button {
                playerState.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            // Repeat
            VStack(spacing: 2) {
                Button {
                    playerState.cycleRepeat()
                } label: {
                    Image(systemName: repeatIcon)
                        .foregroundStyle(playerState.repeatMode != .off ? colors.accent : colors.textTertiary)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(playerState.repeatMode != .off ? colors.accent : .clear)
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var repeatIcon: String {
        switch playerState.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}
