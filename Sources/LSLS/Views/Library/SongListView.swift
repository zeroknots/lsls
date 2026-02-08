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
    @State private var selectedTrackIds: Set<Int64> = []
    @State private var showMergeSheet = false

    private let db = DatabaseManager.shared

    private var selectedTrackInfos: [TrackInfo] {
        tracks.filter { trackInfo in
            guard let id = trackInfo.track.id else { return false }
            return selectedTrackIds.contains(id)
        }
    }

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
                    trackRow(for: trackInfo)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(colors.background)
        .onKeyPress(.escape) {
            if !selectedTrackIds.isEmpty {
                selectedTrackIds.removeAll()
                return .handled
            }
            return .ignored
        }
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
        .sheet(isPresented: $showMergeSheet) {
            MergeTracksView(selectedTracks: selectedTrackInfos) {
                selectedTrackIds.removeAll()
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
        let trackId = trackInfo.track.id ?? -1
        let isPlaying = playerState.currentTrack?.track.id == trackInfo.track.id
        let isInSyncList = trackInfo.track.id.map { syncManager.isTrackInSyncList($0) } ?? false
        let isFavorite = trackInfo.track.isFavorite
        let isInSelection = selectedTrackIds.contains(trackId)

        TrackRow(
            trackInfo: trackInfo,
            isPlaying: isPlaying,
            isSelected: isInSelection,
            isInSyncList: isInSyncList,
            isFavorite: isFavorite,
            playlists: playlists,
            onPlay: { playerState.play(track: trackInfo, fromQueue: tracks) },
            onAddToQueue: { playerState.addToQueueEnd(trackInfo) },
            onSyncToggle: { handleSyncToggle(trackInfo) },
            onAddToPlaylist: { playlist in addTrackToPlaylist(trackInfo, playlist: playlist) },
            onDelete: isInSelection && selectedTrackIds.count >= 2 ? { deleteSelectedTracks() } : { trackToDelete = trackInfo },
            onEdit: isInSelection && selectedTrackIds.count >= 2 ? nil : { trackToEdit = trackInfo },
            onFavoriteToggle: { toggleFavorite(trackInfo) },
            onAnalyzeBPM: { Task { await LibraryManager.analyzeBPM(for: trackInfo.track) } },
            onSelect: { withCommand in
                if withCommand {
                    if selectedTrackIds.contains(trackId) {
                        selectedTrackIds.remove(trackId)
                    } else {
                        selectedTrackIds.insert(trackId)
                    }
                } else {
                    selectedTrackIds.removeAll()
                }
            }
        )
        .contextMenu {
            if isInSelection && selectedTrackIds.count >= 2 {
                Button("Merge...") {
                    showMergeSheet = true
                }

                Divider()

                Button("Delete \(selectedTrackIds.count) Tracks", role: .destructive) {
                    deleteSelectedTracks()
                }
            }
        }
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
        do {
            tracks = try db.dbPool.read { db in
                try LibraryQueries.allTracks(in: db)
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

    private func deleteSelectedTracks() {
        do {
            try db.dbPool.write { dbConn in
                for trackId in selectedTrackIds {
                    if playerState.currentTrack?.track.id == trackId {
                        playerState.playNext()
                    }
                    try LibraryQueries.deleteTrack(trackId, in: dbConn)
                }
            }
            selectedTrackIds.removeAll()
            loadTracks()
        } catch {
            print("Failed to delete tracks: \(error)")
        }
    }
}
