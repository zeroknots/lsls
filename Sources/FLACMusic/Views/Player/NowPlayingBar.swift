import SwiftUI

struct NowPlayingBar: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top edge
            ThemedProgressBar(
                progress: playerState.duration > 0
                    ? playerState.currentTime / playerState.duration : 0,
                height: 4,
                showKnob: true
            ) { fraction in
                playerState.seekFraction(fraction)
            }

            // Controls
            HStack(spacing: 16) {
                // Track info
                HStack(spacing: 12) {
                    if let album = playerState.currentTrack?.album {
                        AlbumArtView(album: album, size: 48)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerState.currentTrack?.track.title ?? "")
                            .font(.system(size: theme.typography.bodySize, weight: .medium))
                            .foregroundStyle(colors.textPrimary)
                            .lineLimit(1)

                        Text(playerState.currentTrack?.artist?.name ?? "")
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: 240, alignment: .leading)

                Spacer()

                // Playback controls
                VStack(spacing: 4) {
                    PlaybackControls()

                    HStack(spacing: 8) {
                        Text(TimeFormatter.format(playerState.currentTime))
                            .font(.system(size: theme.typography.smallCaptionSize).monospacedDigit())
                            .foregroundStyle(colors.textTertiary)

                        Text(TimeFormatter.format(playerState.duration))
                            .font(.system(size: theme.typography.smallCaptionSize).monospacedDigit())
                            .foregroundStyle(colors.textTertiary)
                    }
                }

                Spacer()

                // Volume
                VolumeSlider()
                    .frame(width: 150)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .background(
            Group {
                if theme.effects.useVibrancy {
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)
                        colors.backgroundTertiary.opacity(0.7)
                    }
                } else {
                    colors.backgroundTertiary
                }
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: -4)
    }
}
