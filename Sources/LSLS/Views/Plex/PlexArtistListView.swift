import SwiftUI

struct PlexArtistListView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var artists: [PlexArtist] = []
    @State private var isLoading = false
    @State private var selectedArtist: PlexArtist?
    @State private var albums: [PlexAlbum] = []
    @State private var selectedAlbum: PlexAlbum?

    private var columns: [GridItem] {
        [GridItem(.adaptive(
            minimum: theme.spacing.gridItemSize,
            maximum: theme.spacing.gridItemSize + 30
        ), spacing: theme.spacing.gridSpacing)]
    }

    var body: some View {
        HStack(spacing: 0) {
            // Artist list column
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(artists) { artist in
                            artistRow(artist)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 220)
            .background(colors.backgroundSecondary.opacity(0.5))

            Rectangle()
                .fill(colors.separator)
                .frame(width: 1)

            // Albums for selected artist
            Group {
                if let artist = selectedArtist {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 14) {
                                artistAvatar(size: 56)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artist.title)
                                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                                        .foregroundStyle(colors.textPrimary)
                                    Text("\(albums.count) album\(albums.count == 1 ? "" : "s")")
                                        .font(.system(size: theme.typography.captionSize))
                                        .foregroundStyle(colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, theme.spacing.contentPadding)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                            LazyVGrid(columns: columns, spacing: theme.spacing.sectionSpacing) {
                                ForEach(albums) { album in
                                    PlexAlbumCardSmall(album: album, server: plexState.selectedServer) {
                                        selectedAlbum = album
                                    }
                                }
                            }
                            .padding(.horizontal, theme.spacing.contentPadding)
                            .padding(.bottom, theme.spacing.contentPadding)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background)
                } else {
                    ContentUnavailableView {
                        Label("Select an Artist", systemImage: "music.mic")
                    } description: {
                        Text("Choose an artist to see their albums")
                    }
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background)
                }
            }
        }
        .background(colors.background)
        .task {
            isLoading = true
            let browser = PlexLibraryBrowser(plexState: plexState)
            await browser.fetchArtists()
            artists = browser.artists
            isLoading = false
            if selectedArtist == nil, let first = artists.first {
                selectedArtist = first
            }
        }
        .onChange(of: selectedArtist) {
            loadAlbums()
        }
        .sheet(item: $selectedAlbum) { album in
            PlexAlbumDetailView(album: album)
                .environment(plexState)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func artistRow(_ artist: PlexArtist) -> some View {
        let isSelected = selectedArtist?.id == artist.id

        return Button {
            selectedArtist = artist
        } label: {
            HStack(spacing: 10) {
                artistAvatar(size: 32)

                Text(artist.title)
                    .font(.system(size: theme.typography.bodySize))
                    .foregroundStyle(isSelected ? colors.accent : colors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.shapes.sidebarItemRadius)
                    .fill(isSelected ? colors.accent.opacity(0.1) : .clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private func artistAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(colors.accentSubtle)
                .frame(width: size, height: size)
            Image(systemName: "music.mic")
                .font(.system(size: size * 0.38))
                .foregroundStyle(colors.textTertiary)
        }
    }

    private func loadAlbums() {
        guard let artist = selectedArtist else {
            albums = []
            return
        }
        Task {
            let browser = PlexLibraryBrowser(plexState: plexState)
            albums = await browser.fetchAlbumsForArtist(artist)
        }
    }
}

private struct PlexAlbumCardSmall: View {
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

            if let year = album.year {
                Text(String(year))
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
