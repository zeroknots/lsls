import SwiftUI

struct FullPlayerView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background with ambient color effect
            colors.background
                .ignoresSafeArea()

            if let album = playerState.currentTrack?.album {
                Circle()
                    .fill(colors.accent.opacity(0.12))
                    .blur(radius: 120)
                    .frame(width: 400, height: 400)
                    .offset(y: -60)
            }

            VStack(spacing: 32) {
                // Album art
                if let album = playerState.currentTrack?.album {
                    AlbumArtView(album: album, size: 320)
                        .shadow(
                            color: .black.opacity(0.4),
                            radius: 16, y: 8
                        )
                }

                // Track info
                VStack(spacing: 6) {
                    Text(playerState.currentTrack?.track.title ?? "Not Playing")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(playerState.currentTrack?.artist?.name ?? "")
                        .font(.system(size: theme.typography.headlineSize))
                        .foregroundStyle(colors.textSecondary)

                    if let album = playerState.currentTrack?.album {
                        Text(album.title)
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.textTertiary)
                    }

                    if let format = playerState.currentFormat {
                        Text(format.displayString)
                            .font(.system(size: theme.typography.captionSize).monospacedDigit())
                            .foregroundStyle(colors.textTertiary)
                    }
                }

                // Progress
                VStack(spacing: 4) {
                    ThemedProgressBar(
                        progress: playerState.duration > 0
                            ? playerState.currentTime / playerState.duration : 0,
                        height: 6,
                        showKnob: true
                    ) { fraction in
                        playerState.seekFraction(fraction)
                    }

                    HStack {
                        Text(TimeFormatter.format(playerState.currentTime))
                            .font(.system(size: theme.typography.captionSize).monospacedDigit())
                            .foregroundStyle(colors.textSecondary)
                        Spacer()
                        Text(TimeFormatter.format(playerState.duration))
                            .font(.system(size: theme.typography.captionSize).monospacedDigit())
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                .padding(.horizontal, 40)

                // Controls
                PlaybackControls()
                    .scaleEffect(1.3)

                // Volume
                VolumeSlider()
                    .frame(width: 220)
            }
            .padding(48)
        }
        .frame(minWidth: 400, minHeight: 550)
    }
}
