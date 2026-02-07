import SwiftUI

struct NowPlayingBar: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Main content below the progress bar
            HStack(spacing: 0) {
                // Left: Album art + track info
                HStack(spacing: 14) {
                    if let album = playerState.currentTrack?.album {
                        AlbumArtView(album: album, size: 56)
                    }

                    VStack(alignment: .leading, spacing: 3) {
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
                .frame(minWidth: 180, maxWidth: 280, alignment: .leading)

                Spacer()

                // Center: Transport controls + time
                VStack(spacing: 4) {
                    HStack(spacing: 20) {
                        Button {
                            playerState.playPrevious()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(colors.textPrimary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            playerState.togglePlayPause()
                        } label: {
                            Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(colors.textPrimary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            playerState.playNext()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(colors.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 4) {
                        Text(TimeFormatter.format(playerState.currentTime))
                        Text("/")
                        Text(TimeFormatter.format(playerState.duration))
                    }
                    .font(.system(size: theme.typography.smallCaptionSize).monospacedDigit())
                    .foregroundStyle(colors.textTertiary)
                }

                Spacer()

                // Right: Queue toggle + Volume
                HStack(spacing: 16) {
                    Button {
                        withAnimation {
                            playerState.isQueueVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14))
                            .foregroundStyle(playerState.isQueueVisible ? colors.accent : colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Queue")

                    VolumeSlider()
                        .frame(width: 180)
                }
            }
            .padding(.top, 3) // Account for progress bar height
            .padding(.horizontal, 28)
            .padding(.vertical, 14)

            // Progress bar at absolute top edge
            ThemedProgressBar(
                progress: playerState.duration > 0
                    ? playerState.currentTime / playerState.duration : 0,
                height: 3,
                showKnob: true
            ) { fraction in
                playerState.seekFraction(fraction)
            }
        }
        .background(
            Group {
                if theme.effects.useVibrancy {
                    ZStack {
                        Color.clear.background(.ultraThinMaterial)
                        colors.backgroundTertiary.opacity(0.8)
                    }
                } else {
                    colors.backgroundTertiary
                }
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
    }
}
