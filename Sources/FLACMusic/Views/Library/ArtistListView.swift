import SwiftUI
import GRDB

struct ArtistListView: View {
    @Binding var selectedArtist: Artist?
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @State private var artists: [Artist] = []

    private let db = DatabaseManager.shared

    var body: some View {
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
                        Text(artist.name)
                            .font(.body)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Artists")
        .navigationDestination(for: Artist.self) { artist in
            ArtistDetailView(artist: artist)
                .environment(playerState)
        }
        .task {
            loadArtists()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadArtists()
        }
    }

    private func loadArtists() {
        do {
            artists = try db.dbQueue.read { db in
                try LibraryQueries.allArtists(in: db)
            }
        } catch {
            print("Failed to load artists: \(error)")
        }
    }
}

struct ArtistDetailView: View {
    let artist: Artist
    @Environment(PlayerState.self) private var playerState
    @State private var albums: [AlbumInfo] = []

    private let db = DatabaseManager.shared

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
                        Text(artist.name)
                            .font(.title.bold())
                        Text("\(albums.count) albums")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Albums
                ForEach(albums) { albumInfo in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            AlbumArtView(album: albumInfo.album, size: 80)

                            VStack(alignment: .leading) {
                                Text(albumInfo.album.title)
                                    .font(.headline)
                                if let year = albumInfo.album.year {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationTitle(artist.name)
        .task {
            loadAlbums()
        }
    }

    private func loadAlbums() {
        guard let artistId = artist.id else { return }
        do {
            albums = try db.dbQueue.read { db in
                try LibraryQueries.albumsForArtist(artistId, in: db)
            }
        } catch {
            print("Failed to load albums: \(error)")
        }
    }
}
