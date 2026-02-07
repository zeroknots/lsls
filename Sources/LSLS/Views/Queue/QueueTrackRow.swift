import SwiftUI

struct QueueTrackRow: View {
    let trackInfo: TrackInfo

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            if let album = trackInfo.album {
                AlbumArtView(album: album, size: 32)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colors.backgroundTertiary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textTertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(trackInfo.track.title)
                    .font(.system(size: theme.typography.captionSize))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                if let artist = trackInfo.artist {
                    Text(artist.name)
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(TimeFormatter.format(trackInfo.track.duration))
                .font(.system(size: theme.typography.smallCaptionSize).monospacedDigit())
                .foregroundStyle(colors.textTertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .draggable(LibraryDragItem.track(trackInfo))
    }
}
