import SwiftUI

struct NowPlayingBar: View {
    @Environment(PlayerState.self) private var playerState
    @State private var isDragging = false
    @State private var dragPosition: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(in: geometry.size.width), height: 3)
                }
                .contentShape(Rectangle().inset(by: -8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragPosition = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { _ in
                            playerState.seekFraction(dragPosition)
                            isDragging = false
                        }
                )
            }
            .frame(height: 3)

            // Controls
            HStack(spacing: 16) {
                // Track info
                HStack(spacing: 12) {
                    if let album = playerState.currentTrack?.album {
                        AlbumArtView(album: album, size: 44)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerState.currentTrack?.track.title ?? "")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(playerState.currentTrack?.artist?.name ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 200, alignment: .leading)

                Spacer()

                // Playback controls
                VStack(spacing: 4) {
                    PlaybackControls()

                    HStack(spacing: 8) {
                        Text(TimeFormatter.format(playerState.currentTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text(TimeFormatter.format(playerState.duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Volume
                VolumeSlider()
                    .frame(width: 150)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let fraction: Double
        if isDragging {
            fraction = dragPosition
        } else if playerState.duration > 0 {
            fraction = playerState.currentTime / playerState.duration
        } else {
            fraction = 0
        }
        return totalWidth * CGFloat(max(0, min(1, fraction)))
    }
}
