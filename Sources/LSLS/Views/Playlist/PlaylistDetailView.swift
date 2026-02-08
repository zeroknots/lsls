import SwiftUI
import GRDB

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var tracks: [TrackInfo] = []
    @State private var playlists: [Playlist] = []
    @State private var trackToEdit: TrackInfo? = nil
    @State private var trackToDelete: TrackInfo? = nil

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .fill(
                            LinearGradient(
                                colors: [colors.accent, colors.accentSubtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.name)
                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    Text("\(tracks.count) songs")
                        .foregroundStyle(colors.textSecondary)

                    if !tracks.isEmpty {
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
                        }
                    }
                }

                Spacer()
            }
            .padding(24)

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

            // Track list
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("No Songs", systemImage: "music.note")
                } description: {
                    Text("Add songs to this playlist")
                }
                .foregroundStyle(colors.textSecondary)
            } else {
                List {
                    ForEach(tracks) { trackInfo in
                        trackRow(for: trackInfo)
                    }
                    .onDelete { indexSet in
                        removeTracks(at: indexSet)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(colors.background)
            }
        }
        .background(colors.background)
        .navigationTitle(playlist.name)
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
    }

    @ViewBuilder
    private func trackRow(for trackInfo: TrackInfo) -> some View {
        let isPlaying = playerState.currentTrack?.track.id == trackInfo.track.id
        let isFavorite = trackInfo.track.isFavorite

        TrackRow(
            trackInfo: trackInfo,
            isPlaying: isPlaying,
            isFavorite: isFavorite,
            playlists: playlists,
            onPlay: { playerState.play(track: trackInfo, fromQueue: tracks) },
            onAddToQueue: { playerState.addToQueueEnd(trackInfo) },
            onAddToPlaylist: { targetPlaylist in addTrackToPlaylist(trackInfo, playlist: targetPlaylist) },
            onDelete: { trackToDelete = trackInfo },
            onEdit: { trackToEdit = trackInfo },
            onFavoriteToggle: { toggleFavorite(trackInfo) }
        )
    }

    private func loadTracks() {
        guard let playlistId = playlist.id else { return }
        do {
            tracks = try db.dbPool.read { db in
                try LibraryQueries.playlistTracks(playlistId, in: db)
            }
        } catch {
            print("Failed to load playlist tracks: \(error)")
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

    private func removeTracks(at offsets: IndexSet) {
        guard let playlistId = playlist.id else { return }
        do {
            try db.dbPool.write { dbConn in
                for index in offsets {
                    if let trackId = tracks[index].track.id {
                        try PlaylistTrack
                            .filter(PlaylistTrack.Columns.playlistId == playlistId)
                            .filter(PlaylistTrack.Columns.trackId == trackId)
                            .deleteAll(dbConn)
                    }
                }
            }
            tracks.remove(atOffsets: offsets)
        } catch {
            print("Failed to remove tracks: \(error)")
        }
    }
}
