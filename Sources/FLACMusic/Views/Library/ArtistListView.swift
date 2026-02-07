import SwiftUI
import GRDB

struct ArtistListView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var artists: [Artist] = []
    @State private var selectedArtist: Artist?
    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbum: Album?
    @State private var artistFirstAlbum: [Int64: Album] = [:]

    private let db = DatabaseManager.shared

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
                LazyVStack(spacing: 2) {
                    ForEach(artists) { artist in
                        artistRow(artist)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 220)
            .background(colors.backgroundSecondary.opacity(0.5))

            // Divider
            Rectangle()
                .fill(colors.separator)
                .frame(width: 1)

            // Albums for selected artist
            Group {
                if let artist = selectedArtist {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Artist header
                            HStack(spacing: 14) {
                                artistAvatar(for: artist, size: 56)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(artist.name)
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
                                ForEach(albums) { albumInfo in
                                    AlbumCard(albumInfo: albumInfo) {
                                        selectedAlbum = albumInfo.album
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
            loadArtists()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadArtists()
        }
        .onChange(of: selectedArtist) {
            loadAlbums()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environment(playerState)
                .environment(syncManager)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func artistRow(_ artist: Artist) -> some View {
        let isSelected = selectedArtist?.id == artist.id

        return Button {
            selectedArtist = artist
        } label: {
            HStack(spacing: 10) {
                artistAvatar(for: artist, size: 32)

                Text(artist.name)
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
        .contextMenu {
            if let artistId = artist.id {
                if syncManager.isArtistInSyncList(artistId) {
                    Button("Remove Artist from Sync List", role: .destructive) {
                        if let item = syncManager.syncItems.first(where: { $0.itemType == .artist && $0.artistId == artistId }) {
                            syncManager.removeSyncItem(item)
                        }
                    }
                } else {
                    Button("Add Artist to Sync List") {
                        syncManager.addArtist(artistId)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artistAvatar(for artist: Artist, size: CGFloat) -> some View {
        if let artistId = artist.id,
           let album = artistFirstAlbum[artistId],
           let image = ArtworkCache.shared.artwork(for: album) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(colors.accentSubtle)
                    .frame(width: size, height: size)
                Image(systemName: "music.mic")
                    .font(.system(size: size * 0.38))
                    .foregroundStyle(colors.textTertiary)
            }
        }
    }

    private func loadArtists() {
        do {
            artists = try db.dbQueue.read { db in
                try LibraryQueries.allArtists(in: db)
            }
            loadArtistArtwork()
            if selectedArtist == nil, let first = artists.first {
                selectedArtist = first
            }
        } catch {
            print("Failed to load artists: \(error)")
        }
    }

    private func loadArtistArtwork() {
        do {
            let allAlbums = try db.dbQueue.read { db in
                try LibraryQueries.allAlbums(in: db)
            }
            var lookup: [Int64: Album] = [:]
            for albumInfo in allAlbums {
                if let artistId = albumInfo.album.artistId, lookup[artistId] == nil {
                    lookup[artistId] = albumInfo.album
                }
            }
            artistFirstAlbum = lookup
        } catch {
            print("Failed to load artist artwork: \(error)")
        }
    }

    private func loadAlbums() {
        guard let artistId = selectedArtist?.id else {
            albums = []
            return
        }
        do {
            albums = try db.dbQueue.read { db in
                try LibraryQueries.albumsForArtist(artistId, in: db)
            }
        } catch {
            print("Failed to load albums: \(error)")
        }
    }
}
