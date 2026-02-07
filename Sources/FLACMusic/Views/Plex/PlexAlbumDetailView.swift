import SwiftUI

struct PlexAlbumDetailView: View {
    let album: PlexAlbum
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @Environment(\.dismiss) private var dismiss
    @State private var tracks: [PlexTrack] = []
    @State private var trackInfos: [TrackInfo] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 20) {
                // Album artwork
                Group {
                    if let server = plexState.selectedServer, let url = album.artworkURL(server: server) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            artworkPlaceholder
                        }
                    } else {
                        artworkPlaceholder
                    }
                }
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.title.bold())

                    if let artist = album.parentTitle {
                        Text(artist)
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
                            if let first = trackInfos.first {
                                playerState.play(track: first, fromQueue: trackInfos)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Shuffle") {
                            if let random = trackInfos.randomElement() {
                                playerState.shuffleEnabled = true
                                playerState.play(track: random, fromQueue: trackInfos)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.top, 8)
                    .disabled(trackInfos.isEmpty)
                }

                Spacer()
            }
            .padding(24)

            Divider()

            // Track list
            if isLoading {
                ProgressView()
                    .padding(.top, 40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(trackInfos) { trackInfo in
                            TrackRow(
                                trackInfo: trackInfo,
                                showAlbum: false,
                                isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id
                            ) {
                                playerState.play(track: trackInfo, fromQueue: trackInfos)
                            }
                            Divider().padding(.leading, 50)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .task {
            isLoading = true
            let browser = PlexLibraryBrowser(plexState: plexState)
            tracks = await browser.fetchTracksForAlbum(album)
            trackInfos = browser.makeTrackInfos(from: tracks, album: album)
            isLoading = false
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 200 * 0.3))
                .foregroundStyle(.secondary)
        }
    }

    private var totalDuration: String {
        let total = tracks.reduce(0.0) { $0 + $1.durationSeconds }
        return TimeFormatter.formatLong(total)
    }
}
