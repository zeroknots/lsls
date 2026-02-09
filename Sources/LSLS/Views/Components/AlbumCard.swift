import SwiftUI
import AppKit

struct AlbumCard: View {
    let albumInfo: AlbumInfo
    var isSelected: Bool = false
    var onTap: ((_ withCommand: Bool) -> Void)?

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    private var size: CGFloat { CGFloat(theme.spacing.gridItemSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AlbumArtView(album: albumInfo.album, size: size)

                if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .fill(.black.opacity(0.3))
                        .frame(width: size, height: size)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .stroke(colors.accent, lineWidth: 2.5)
                        .frame(width: size, height: size)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, colors.accent)
                        .padding(6)
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
        .onHover { hovering in
            withTransaction(Transaction(animation: nil)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            let withCommand = NSEvent.modifierFlags.contains(.command)
            onTap?(withCommand)
        }
        .draggable(LibraryDragItem.album(albumInfo))
    }
}
