import SwiftUI

struct AlbumArtView: View {
    let album: Album?
    var size: CGFloat = 160
    var artworkURL: URL? = nil

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
            } else if let album, let image = ArtworkCache.shared.artwork(for: album) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                .stroke(colors.separator.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(theme.effects.albumArtShadowOpacity),
            radius: theme.effects.albumArtShadowRadius,
            y: 2
        )
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [colors.placeholderGradientStart, colors.placeholderGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3))
                .foregroundStyle(colors.textTertiary)
        }
    }
}
