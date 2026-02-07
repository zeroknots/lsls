import SwiftUI

struct AlbumCard: View {
    let albumInfo: AlbumInfo
    var onTap: (() -> Void)?

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    private var size: CGFloat { CGFloat(theme.spacing.gridItemSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AlbumArtView(album: albumInfo.album, size: size)

                if isHovered {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .fill(.black.opacity(0.3))
                        .frame(width: size, height: size)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Text(albumInfo.album.title)
                .font(.system(size: theme.typography.bodySize, weight: .medium))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .padding(.leading, 2)

            if let artist = albumInfo.artist {
                Text(artist.name)
                    .font(.system(size: theme.typography.captionSize))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .padding(.leading, 2)
            }
        }
        .frame(width: size)
        .scaleEffect(isHovered ? theme.effects.hoverScale : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture { onTap?() }
    }
}
