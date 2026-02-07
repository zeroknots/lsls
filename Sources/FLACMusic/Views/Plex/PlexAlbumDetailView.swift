import SwiftUI

struct PlexAlbumDetailView: View {
    let album: PlexAlbum
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var tracks: [PlexTrack] = []
    @State private var trackInfos: [TrackInfo] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 20) {
                AlbumArtView(
                    album: nil,
                    size: 220,
                    artworkURL: plexState.selectedServer.flatMap { album.artworkURL(server: $0) }
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    if let artist = album.parentTitle {
                        Text(artist)
                            .font(.system(size: theme.typography.headlineSize))
                            .foregroundStyle(colors.textSecondary)
                    }

                    if let year = album.year {
                        Text(String(year))
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.textTertiary)
                    }

                    Text("\(tracks.count) songs · \(totalDuration)")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)

                    HStack(spacing: 12) {
                        Button("Play All") {
                            if let first = trackInfos.first {
                                playerState.play(track: first, fromQueue: trackInfos)
                            }
                        }
                        .buttonStyle(AccentFilledButtonStyle())

                        Button("Shuffle") {
                            if let random = trackInfos.randomElement() {
                                playerState.shuffleEnabled = true
                                playerState.play(track: random, fromQueue: trackInfos)
                            }
                        }
                        .buttonStyle(AccentOutlineButtonStyle())
                    }
                    .padding(.top, 8)
                    .disabled(trackInfos.isEmpty)
                }

                Spacer()
            }
            .padding(28)

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

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
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(colors.background)
        .task {
            isLoading = true
            let browser = PlexLibraryBrowser(plexState: plexState)
            tracks = await browser.fetchTracksForAlbum(album)
            trackInfos = browser.makeTrackInfos(from: tracks, album: album)
            isLoading = false
        }
    }

    private var totalDuration: String {
        let total = tracks.reduce(0.0) { $0 + $1.durationSeconds }
        return TimeFormatter.formatLong(total)
    }
}
