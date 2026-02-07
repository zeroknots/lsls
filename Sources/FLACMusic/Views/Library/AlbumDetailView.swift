import SwiftUI
import GRDB

struct AlbumDetailView: View {
    let album: Album
    @Environment(PlayerState.self) private var playerState
    @Environment(\.dismiss) private var dismiss
    @State private var tracks: [TrackInfo] = []
    @State private var artist: Artist?

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 20) {
                AlbumArtView(album: album, size: 200)

                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.title.bold())

                    if let artist {
                        Text(artist.name)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    if let year = album.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    Text("\(tracks.count) songs · \(totalDuration)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Play All") {
                            if let first = tracks.first {
                                playerState.play(track: first, fromQueue: tracks)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Shuffle") {
                            if let random = tracks.randomElement() {
                                playerState.shuffleEnabled = true
                                playerState.play(track: random, fromQueue: tracks)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(24)

            Divider()

            // Track list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tracks) { trackInfo in
                        TrackRow(
                            trackInfo: trackInfo,
                            showAlbum: false,
                            isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id
                        ) {
                            playerState.play(track: trackInfo, fromQueue: tracks)
                        }
                        Divider().padding(.leading, 50)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task {
            loadTracks()
        }
    }

    private func loadTracks() {
        guard let albumId = album.id else { return }
        do {
            tracks = try db.dbQueue.read { db in
                try LibraryQueries.tracksForAlbum(albumId, in: db)
            }
            if let artistId = album.artistId {
                artist = try db.dbQueue.read { db in
                    try Artist.fetchOne(db, id: artistId)
                }
            }
        } catch {
            print("Failed to load tracks: \(error)")
        }
    }

    private var totalDuration: String {
        let total = tracks.reduce(0) { $0 + $1.track.duration }
        return TimeFormatter.formatLong(total)
    }
}
