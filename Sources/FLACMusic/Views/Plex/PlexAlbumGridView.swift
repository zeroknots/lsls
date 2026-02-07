import SwiftUI

struct PlexAlbumGridView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(PlayerState.self) private var playerState
    @State private var browser: PlexLibraryBrowser?
    @State private var albums: [PlexAlbum] = []
    @State private var selectedAlbum: PlexAlbum?
    @State private var isLoading = false

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if albums.isEmpty {
                ContentUnavailableView {
                    Label("No Albums", systemImage: "music.note")
                } description: {
                    Text("No albums found in your Plex library")
                }
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(albums) { album in
                        PlexAlbumCard(album: album, server: plexState.selectedServer)
                            .onTapGesture {
                                selectedAlbum = album
                            }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Plex Albums")
        .task {
            let b = PlexLibraryBrowser(plexState: plexState)
            browser = b
            isLoading = true
            await b.fetchAlbums()
            albums = b.albums
            isLoading = false
        }
        .sheet(item: $selectedAlbum) { album in
            PlexAlbumDetailView(album: album)
                .environment(plexState)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}

private struct PlexAlbumCard: View {
    let album: PlexAlbum
    let server: PlexServer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let server, let url = album.artworkURL(server: server) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        albumPlaceholder
                    }
                } else {
                    albumPlaceholder
                }
            }
            .frame(width: 170, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            Text(album.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            if let artist = album.parentTitle {
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 170)
    }

    private var albumPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 170 * 0.3))
                .foregroundStyle(.secondary)
        }
    }
}
