import SwiftUI
import GRDB

struct SongListView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
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
            } else {
                ForEach(tracks) { trackInfo in
                    TrackRow(
                        trackInfo: trackInfo,
                        isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id
                    ) {
                        playerState.play(track: trackInfo, fromQueue: tracks)
                    }
                }
            }
        }
        .listStyle(.inset)
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
