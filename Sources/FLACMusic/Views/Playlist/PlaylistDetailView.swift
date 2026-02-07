import SwiftUI
import GRDB

struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var tracks: [TrackInfo] = []

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
                        TrackRow(
                            trackInfo: trackInfo,
                            isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id
                        ) {
                            playerState.play(track: trackInfo, fromQueue: tracks)
                        }
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
        }
    }

    private func loadTracks() {
        guard let playlistId = playlist.id else { return }
        do {
            tracks = try db.dbQueue.read { db in
                try LibraryQueries.playlistTracks(playlistId, in: db)
            }
        } catch {
            print("Failed to load playlist tracks: \(error)")
        }
    }

    private func removeTracks(at offsets: IndexSet) {
        guard let playlistId = playlist.id else { return }
        do {
            try db.dbQueue.write { dbConn in
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
