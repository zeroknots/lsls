import SwiftUI
import GRDB

private struct ArtistAvatarView: View {
    let album: Album?
    let size: CGFloat

    @Environment(\.themeColors) private var colors
    @State private var image: NSImage?

    var body: some View {
        let displayImage = image ?? album.flatMap({ ArtworkCache.shared.cachedArtwork(for: $0) })

        Group {
            if let displayImage {
                Image(nsImage: displayImage)
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
        .task(id: album?.id) {
            guard let album, image == nil else { return }
            image = await ArtworkCache.shared.loadArtwork(for: album)
        }
    }
}

struct ArtistListView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var artists: [Artist] = []
    @State private var selectedArtist: Artist?
    @State private var albums: [AlbumInfo] = []
    @State private var albumTracks: [Int64: [TrackInfo]] = [:]
    @Binding var selectedAlbum: Album?
    @State private var artistFirstAlbum: [Int64: Album] = [:]
    @State private var playlists: [Playlist] = []
    @State private var trackToEdit: TrackInfo? = nil
    @State private var trackToDelete: TrackInfo? = nil
    @State private var albumToDelete: AlbumInfo? = nil

    private let db = DatabaseManager.shared

    var body: some View {
        artistBrowser
        .background(colors.background)
        .task {
            loadArtists()
            loadPlaylists()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadArtists()
        }
        .onChange(of: selectedArtist) {
            loadAlbums()
        }
        .sheet(item: $trackToEdit) { trackInfo in
            TrackEditView(trackInfo: trackInfo) {
                loadAlbums()
            }
        }
        .alert("Delete Track?", isPresented: Binding(
            get: { trackToDelete != nil },
            set: { if !$0 { trackToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { trackToDelete = nil }
            Button("Delete", role: .destructive) {
                if let track = trackToDelete {
                    deleteTrack(track)
                    trackToDelete = nil
                }
            }
        } message: {
            Text("This will remove \"\(trackToDelete?.track.title ?? "")\" from your library and all playlists.")
        }
        .alert("Delete Album?", isPresented: Binding(
            get: { albumToDelete != nil },
            set: { if !$0 { albumToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { albumToDelete = nil }
            Button("Delete", role: .destructive) {
                if let albumInfo = albumToDelete, let albumId = albumInfo.album.id {
                    deleteAlbum(albumId)
                    albumToDelete = nil
                }
            }
        } message: {
            Text("This will delete \"\(albumToDelete?.album.title ?? "")\" and all its tracks.")
        }
    }

    private var artistBrowser: some View {
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

            Rectangle()
                .fill(colors.separator)
                .frame(width: 1)

            // Artist detail: name pinned at top, albums + tracks scrollable
            Group {
                if let artist = selectedArtist {
                    VStack(alignment: .leading, spacing: 0) {
                        // Pinned artist header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artist.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(colors.textPrimary)

                            let totalSongs = albumTracks.values.reduce(0) { $0 + $1.count }
                            Text("\(albums.count) album\(albums.count == 1 ? "" : "s"), \(totalSongs) song\(totalSongs == 1 ? "" : "s")")
                                .font(.system(size: theme.typography.captionSize))
                                .foregroundStyle(colors.textSecondary)
                        }
                        .padding(.horizontal, theme.spacing.contentPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        Rectangle()
                            .fill(colors.separator)
                            .frame(height: 1)

                        // Scrollable albums + tracks
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(albums) { albumInfo in
                                    albumSection(albumInfo)

                                    if albumInfo.id != albums.last?.id {
                                        Rectangle()
                                            .fill(colors.separator)
                                            .frame(height: 1)
                                            .padding(.horizontal, theme.spacing.contentPadding)
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(.bottom, theme.spacing.contentPadding)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }

    private func albumSection(_ albumInfo: AlbumInfo) -> some View {
        let tracks = albumTracks[albumInfo.album.id ?? -1] ?? []
        let allArtistTracks = albums.flatMap { albumTracks[$0.album.id ?? -1] ?? [] }

        return VStack(alignment: .leading, spacing: 0) {
            // Album header: art + title + year
            HStack(spacing: 16) {
                AlbumArtView(album: albumInfo.album, size: 210)
                    .onTapGesture {
                        selectedAlbum = albumInfo.album
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(albumInfo.album.title)
                        .font(.system(size: theme.typography.headlineSize, weight: .semibold))
                        .foregroundStyle(colors.textPrimary)

                    if let year = albumInfo.album.year {
                        Text(String(year))
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.textTertiary)
                    }

                    Text("\(tracks.count) song\(tracks.count == 1 ? "" : "s")")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacing.contentPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .contextMenu {
                if let albumId = albumInfo.album.id {
                    if syncManager.isAlbumInSyncList(albumId) {
                        Button("Remove Album from Sync List", role: .destructive) {
                            if let item = syncManager.syncItems.first(where: { $0.itemType == .album && $0.albumId == albumId }) {
                                syncManager.removeSyncItem(item)
                            }
                        }
                    } else {
                        Button("Add Album to Sync List") {
                            syncManager.addAlbum(albumId)
                        }
                    }

                    Divider()

                    Button("Delete Album", role: .destructive) {
                        albumToDelete = albumInfo
                    }
                }
            }

            // Track list for this album
            ForEach(tracks) { trackInfo in
                albumTrackRow(for: trackInfo, allArtistTracks: allArtistTracks)
            }
            .padding(.horizontal, 8)
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
        .draggable(LibraryDragItem.artist(artist))
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
    private func albumTrackRow(for trackInfo: TrackInfo, allArtistTracks: [TrackInfo]) -> some View {
        let isPlaying = playerState.currentTrack?.track.id == trackInfo.track.id
        let isInSyncList = trackInfo.track.id.map { syncManager.isTrackInSyncList($0) } ?? false
        let isFavorite = trackInfo.track.isFavorite

        TrackRow(
            trackInfo: trackInfo,
            showAlbum: false,
            isPlaying: isPlaying,
            isInSyncList: isInSyncList,
            isFavorite: isFavorite,
            playlists: playlists,
            onPlay: { playerState.play(track: trackInfo, fromQueue: allArtistTracks) },
            onAddToQueue: { playerState.addToQueueEnd(trackInfo) },
            onSyncToggle: { handleSyncToggle(trackInfo) },
            onAddToPlaylist: { playlist in addTrackToPlaylist(trackInfo, playlist: playlist) },
            onDelete: { trackToDelete = trackInfo },
            onEdit: { trackToEdit = trackInfo },
            onFavoriteToggle: { toggleFavorite(trackInfo) }
        )
    }

    private func handleSyncToggle(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        if syncManager.isTrackInSyncList(trackId) {
            if let item = syncManager.syncItems.first(where: { $0.itemType == .track && $0.trackId == trackId }) {
                syncManager.removeSyncItem(item)
            }
        } else {
            syncManager.addTrack(trackId)
        }
    }

    private func artistAvatar(for artist: Artist, size: CGFloat) -> some View {
        let album = artist.id.flatMap { artistFirstAlbum[$0] }
        return ArtistAvatarView(album: album, size: size)
    }

    private func loadArtists() {
        do {
            artists = try db.dbPool.read { db in
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
            let allAlbums = try db.dbPool.read { db in
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
            albumTracks = [:]
            return
        }
        do {
            albums = try db.dbPool.read { db in
                try LibraryQueries.albumsForArtist(artistId, in: db)
            }
            // Load tracks for each album
            var tracks: [Int64: [TrackInfo]] = [:]
            for albumInfo in albums {
                guard let albumId = albumInfo.album.id else { continue }
                tracks[albumId] = try db.dbPool.read { db in
                    try LibraryQueries.tracksForAlbum(albumId, in: db)
                }
            }
            albumTracks = tracks
        } catch {
            print("Failed to load albums: \(error)")
        }
    }

    private func loadPlaylists() {
        do {
            playlists = try db.dbPool.read { db in
                try LibraryQueries.allPlaylists(in: db)
            }
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    private func addTrackToPlaylist(_ trackInfo: TrackInfo, playlist: Playlist) {
        guard let trackId = trackInfo.track.id, let playlistId = playlist.id else { return }
        do {
            try db.dbPool.write { dbConn in
                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
            }
        } catch {
            print("Failed to add track to playlist: \(error)")
        }
    }

    private func toggleFavorite(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        try? db.dbPool.write { dbConn in
            try LibraryQueries.toggleFavorite(trackId: trackId, in: dbConn)
        }
        loadAlbums()
    }

    private func deleteTrack(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        if playerState.currentTrack?.track.id == trackId {
            playerState.playNext()
        }
        do {
            try db.dbPool.write { dbConn in
                try LibraryQueries.deleteTrack(trackId, in: dbConn)
            }
            loadAlbums()
        } catch {
            print("Failed to delete track: \(error)")
        }
    }

    private func deleteAlbum(_ albumId: Int64) {
        do {
            try db.dbPool.write { dbConn in
                try LibraryQueries.deleteAlbum(albumId, in: dbConn)
            }
            loadAlbums()
        } catch {
            print("Failed to delete album: \(error)")
        }
    }
}
