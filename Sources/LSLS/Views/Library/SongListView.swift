import SwiftUI
import GRDB

struct SongListView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(SyncManager.self) private var syncManager
    @State private var tracks: [TrackInfo] = []
    @State private var playlists: [Playlist] = []
    @State private var trackToEdit: TrackInfo? = nil
    @State private var trackToDelete: TrackInfo? = nil

    private let db = DatabaseManager.shared

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("No Songs", systemImage: "music.note")
                } description: {
                    Text("Import a folder to get started")
                }
                .foregroundStyle(colors.textSecondary)
            } else {
                ForEach(tracks) { trackInfo in
                    TrackRow(
                        trackInfo: trackInfo,
                        isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id,
                        isInSyncList: trackInfo.track.id.map { syncManager.isTrackInSyncList($0) } ?? false,
                        playlists: playlists
                    ) {
                        playerState.play(track: trackInfo, fromQueue: tracks)
                    } onSyncToggle: {
                        guard let trackId = trackInfo.track.id else { return }
                        if syncManager.isTrackInSyncList(trackId) {
                            if let item = syncManager.syncItems.first(where: { $0.itemType == .track && $0.trackId == trackId }) {
                                syncManager.removeSyncItem(item)
                            }
                        } else {
                            syncManager.addTrack(trackId)
                        }
                    } onAddToPlaylist: { playlist in
                        addTrackToPlaylist(trackInfo, playlist: playlist)
                    } onDelete: {
                        trackToDelete = trackInfo
                    } onEdit: {
                        trackToEdit = trackInfo
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(colors.background)
        .navigationTitle("Songs")
        .task {
            loadTracks()
            loadPlaylists()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadTracks()
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

    private func loadTracks() {
        do {
            tracks = try db.dbQueue.read { db in
                try LibraryQueries.allTracks(in: db)
            }
        } catch {
            print("Failed to load tracks: \(error)")
        }
    }

    private func loadPlaylists() {
        do {
            playlists = try db.dbQueue.read { db in
                try LibraryQueries.allPlaylists(in: db)
            }
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    private func addTrackToPlaylist(_ trackInfo: TrackInfo, playlist: Playlist) {
        guard let trackId = trackInfo.track.id, let playlistId = playlist.id else { return }
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
            }
        } catch {
            print("Failed to add track to playlist: \(error)")
        }
    }

    private func deleteTrack(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        if playerState.currentTrack?.track.id == trackId {
            playerState.playNext()
        }
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.deleteTrack(trackId, in: dbConn)
            }
            loadTracks()
        } catch {
            print("Failed to delete track: \(error)")
        }
    }
}
