import SwiftUI
import GRDB

struct SongListView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(SyncManager.self) private var syncManager
    @State private var tracks: [TrackInfo] = []

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
                        isInSyncList: trackInfo.track.id.map { syncManager.isTrackInSyncList($0) } ?? false
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
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadTracks()
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
}
