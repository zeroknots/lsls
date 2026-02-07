import SwiftUI

struct PlexArtistListView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @State private var artists: [PlexArtist] = []
    @State private var isLoading = false
    @State private var selectedArtist: PlexArtist?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(artists, selection: $selectedArtist) { artist in
                    NavigationLink(value: artist) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(.quaternary)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "music.mic")
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading) {
                                Text(artist.title)
                                    .font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationDestination(for: PlexArtist.self) { artist in
                    PlexArtistDetailView(artist: artist)
                        .environment(plexState)
                        .environment(playerState)
                }
            }
        }
        .navigationTitle("Plex Artists")
        .task {
            isLoading = true
            let browser = PlexLibraryBrowser(plexState: plexState)
            await browser.fetchArtists()
            artists = browser.artists
            isLoading = false
        }
    }
}

struct PlexArtistDetailView: View {
    let artist: PlexArtist
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @State private var albums: [PlexAlbum] = []
    @State private var selectedAlbum: PlexAlbum?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Artist header
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 80, height: 80)
                        Image(systemName: "music.mic")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text(artist.title)
                            .font(.title.bold())
                        Text("\(albums.count) albums")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Albums
                ForEach(albums) { album in
                    HStack(spacing: 12) {
                        Group {
                            if let server = plexState.selectedServer, let url = album.artworkURL(server: server) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.quaternary)
                                        .overlay {
                                            Image(systemName: "music.note")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary)
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading) {
                            Text(album.title)
                                .font(.headline)
                            if let year = album.year {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAlbum = album
                    }
                }
            }
        }
        .navigationTitle(artist.title)
        .task {
            let browser = PlexLibraryBrowser(plexState: plexState)
            albums = await browser.fetchAlbumsForArtist(artist)
        }
        .sheet(item: $selectedAlbum) { album in
            PlexAlbumDetailView(album: album)
                .environment(plexState)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}
