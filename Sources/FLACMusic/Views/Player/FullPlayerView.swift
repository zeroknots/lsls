import SwiftUI

struct FullPlayerView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            // Album art
            if let album = playerState.currentTrack?.album {
                AlbumArtView(album: album, size: 300)
            }

            // Track info
            VStack(spacing: 8) {
                Text(playerState.currentTrack?.track.title ?? "Not Playing")
                    .font(.title2.bold())

                Text(playerState.currentTrack?.artist?.name ?? "")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if let album = playerState.currentTrack?.album {
                    Text(album.title)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress
            VStack(spacing: 4) {
                Slider(
                    value: .init(
                        get: { playerState.duration > 0 ? playerState.currentTime / playerState.duration : 0 },
                        set: { playerState.seekFraction($0) }
                    ),
                    in: 0...1
                )

                HStack {
                    Text(TimeFormatter.format(playerState.currentTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TimeFormatter.format(playerState.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)

            // Controls
            PlaybackControls()
                .scaleEffect(1.2)

            // Volume
            VolumeSlider()
                .frame(width: 200)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 500)
    }
}
