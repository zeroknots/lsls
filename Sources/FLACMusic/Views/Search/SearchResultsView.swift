import SwiftUI
import GRDB

struct SearchResultsView: View {
    @Binding var searchText: String
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var tracks: [TrackInfo] = []
    @State private var albums: [AlbumInfo] = []
    @State private var artists: [Artist] = []
    @State private var selectedAlbum: Album?

    private let db = DatabaseManager.shared

    var body: some View {
        ScrollView {
            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("Search", systemImage: "magnifyingglass")
                } description: {
                    Text("Search for songs, albums, and artists")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else if tracks.isEmpty && albums.isEmpty && artists.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No results for \"\(searchText)\"")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !artists.isEmpty {
                        Section {
                            ForEach(artists) { artist in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(colors.accentSubtle)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "music.mic")
                                            .foregroundStyle(colors.accent)
                                    }
                                    Text(artist.name)
                                        .foregroundStyle(colors.textPrimary)
                                }
                                .padding(.horizontal, 24)
                            }
                        } header: {
                            Text("Artists")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }

                    if !albums.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(albums) { albumInfo in
                                        VStack(alignment: .leading, spacing: 6) {
                                            AlbumArtView(album: albumInfo.album, size: 140)

                                            Text(albumInfo.album.title)
                                                .font(.system(size: theme.typography.captionSize, weight: .medium))
                                                .foregroundStyle(colors.textPrimary)
                                                .lineLimit(1)

                                            if let artist = albumInfo.artist {
                                                Text(artist.name)
                                                    .font(.system(size: theme.typography.smallCaptionSize))
                                                    .foregroundStyle(colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(width: 140)
                                        .onTapGesture {
                                            selectedAlbum = albumInfo.album
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        } header: {
                            Text("Albums")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }

                    if !tracks.isEmpty {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(tracks) { trackInfo in
                                    TrackRow(
                                        trackInfo: trackInfo,
                                        isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id
                                    ) {
                                        playerState.play(track: trackInfo, fromQueue: tracks)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        } header: {
                            Text("Songs")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .background(colors.background)
        .navigationTitle("Search")
        .onChange(of: searchText) { _, newValue in
            performSearch(newValue)
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            tracks = []
            albums = []
            artists = []
            return
        }
        do {
            let results = try db.dbQueue.read { db in
                try LibraryQueries.search(query, in: db)
            }
            tracks = results.tracks
            albums = results.albums
            artists = results.artists
        } catch {
            print("Search failed: \(error)")
        }
    }
}
