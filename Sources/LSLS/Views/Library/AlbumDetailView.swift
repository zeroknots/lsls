import SwiftUI
import GRDB

struct AlbumDetailView: View {
    let album: Album
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @Environment(VimNavigation.self) private var vimNav
    @State private var tracks: [TrackInfo] = []
    @State private var artist: Artist?
    @State private var playlists: [Playlist] = []
    @State private var trackToEdit: TrackInfo? = nil
    @State private var trackToDelete: TrackInfo? = nil

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 20) {
                AlbumArtView(album: album, size: 200)

                VStack(alignment: .leading, spacing: 6) {
                    Text(album.title)
                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    if let artist {
                        Text(artist.name)
                            .font(.system(size: theme.typography.headlineSize))
                            .foregroundStyle(colors.textSecondary)
                    }

                    HStack(spacing: 8) {
                        if let year = album.year {
                            Text(String(year))
                                .foregroundStyle(colors.textTertiary)
                        }
                        Text("\(tracks.count) songs · \(totalDuration)")
                            .foregroundStyle(colors.textTertiary)
                    }
                    .font(.system(size: theme.typography.captionSize))

                    HStack(spacing: 12) {
                        Button("Play All") {
                            if let first = tracks.first {
                                playerState.play(track: first, fromQueue: tracks)
                            }
                        }
                        .buttonStyle(AccentFilledButtonStyle())

                        Button("Shuffle") {
                            if let random = tracks.randomElement() {
                                playerState.shuffleEnabled = true
                                playerState.play(track: random, fromQueue: tracks)
                            }
                        }
                        .buttonStyle(AccentOutlineButtonStyle())

                        if let albumId = album.id {
                            if syncManager.isAlbumInSyncList(albumId) {
                                Button {
                                    if let item = syncManager.syncItems.first(where: { $0.itemType == .album && $0.albumId == albumId }) {
                                        syncManager.removeSyncItem(item)
                                    }
                                } label: {
                                    Label("Synced", systemImage: "checkmark.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .tint(.green)
                            } else {
                                Button {
                                    syncManager.addAlbum(albumId)
                                } label: {
                                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(28)

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

            // Track list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, trackInfo in
                            let isVimHighlighted = vimNav.isActive && vimNav.focusZone == .content && index == vimNav.contentIndex
                            trackRow(for: trackInfo)
                                .id(trackInfo.id)
                                .overlay(alignment: .leading) {
                                    if isVimHighlighted {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(colors.accent)
                                            .frame(width: 3)
                                            .padding(.vertical, 4)
                                    }
                                }
                                .background {
                                    if isVimHighlighted {
                                        RoundedRectangle(cornerRadius: 6).fill(colors.accent.opacity(0.08))
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: vimNav.contentIndex) { _, newIndex in
                    guard vimNav.isActive, vimNav.focusZone == .content else { return }
                    if newIndex >= 0 && newIndex < tracks.count {
                        withAnimation { proxy.scrollTo(tracks[newIndex].id, anchor: .center) }
                    }
                }
            }
        }
        .background(colors.background)
        .task {
            loadTracks()
            loadPlaylists()
        }
        .sheet(item: $trackToEdit) { trackInfo in
            TrackEditView(trackInfo: trackInfo) {
                loadTracks()
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
        .onChange(of: vimNav.enterTrigger) {
            guard vimNav.isActive, vimNav.focusZone == .content else { return }
            guard vimNav.contentIndex >= 0 && vimNav.contentIndex < tracks.count else { return }
            playerState.play(track: tracks[vimNav.contentIndex], fromQueue: tracks)
        }
    }

    @ViewBuilder
    private func trackRow(for trackInfo: TrackInfo) -> some View {
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
            onPlay: { playerState.play(track: trackInfo, fromQueue: tracks) },
            onAddToQueue: { playerState.addToQueueEnd(trackInfo) },
            onSyncToggle: { handleSyncToggle(trackInfo) },
            onAddToPlaylist: { playlist in addTrackToPlaylist(trackInfo, playlist: playlist) },
            onDelete: { trackToDelete = trackInfo },
            onEdit: { trackToEdit = trackInfo },
            onFavoriteToggle: { toggleFavorite(trackInfo) },
            onAnalyzeBPM: { Task { await LibraryManager.analyzeBPM(for: trackInfo.track) } }
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

    private func loadTracks() {
        guard let albumId = album.id else { return }
        do {
            tracks = try db.dbPool.read { db in
                try LibraryQueries.tracksForAlbum(albumId, in: db)
            }
            vimNav.contentItemCount = tracks.count
            if let artistId = album.artistId {
                artist = try db.dbPool.read { db in
                    try Artist.fetchOne(db, id: artistId)
                }
            }
        } catch {
            print("Failed to load tracks: \(error)")
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
        loadTracks()
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
            loadTracks()
        } catch {
            print("Failed to delete track: \(error)")
        }
    }

    private var totalDuration: String {
        let total = tracks.reduce(0) { $0 + $1.track.duration }
        return TimeFormatter.formatLong(total)
    }
}
