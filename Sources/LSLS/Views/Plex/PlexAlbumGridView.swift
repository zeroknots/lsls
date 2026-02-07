import SwiftUI

struct PlexAlbumGridView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var browser: PlexLibraryBrowser?
    @State private var albums: [PlexAlbum] = []
    @State private var selectedAlbum: PlexAlbum?
    @State private var isLoading = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(
            minimum: theme.spacing.gridItemSize,
            maximum: theme.spacing.gridItemSize + 30
        ), spacing: theme.spacing.gridSpacing)]
    }

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if albums.isEmpty {
                ContentUnavailableView {
                    Label("No Albums", systemImage: "music.note")
                } description: {
                    Text("No albums found in your Plex library")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: theme.spacing.sectionSpacing) {
                    ForEach(albums) { album in
                        PlexAlbumCard(album: album, server: plexState.selectedServer) {
                            selectedAlbum = album
                        }
                    }
                }
                .padding(theme.spacing.contentPadding)
            }
        }
        .background(colors.background)
        .navigationTitle("Plex Albums")
        .task {
            let b = PlexLibraryBrowser(plexState: plexState)
            browser = b
            isLoading = true
            await b.fetchAlbums()
            albums = b.albums
            isLoading = false
        }
        .sheet(item: $selectedAlbum) { album in
            PlexAlbumDetailView(album: album)
                .environment(plexState)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

private struct PlexAlbumCard: View {
    let album: PlexAlbum
    let server: PlexServer?
    var onTap: (() -> Void)?

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    private var size: CGFloat { CGFloat(theme.spacing.gridItemSize) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AlbumArtView(
                    album: nil,
                    size: size,
                    artworkURL: server.flatMap { album.artworkURL(server: $0) }
                )

                if isHovered {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .fill(.black.opacity(0.3))
                        .frame(width: size, height: size)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Text(album.title)
                .font(.system(size: theme.typography.bodySize, weight: .medium))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .padding(.leading, 2)

            if let artist = album.parentTitle {
                Text(artist)
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
