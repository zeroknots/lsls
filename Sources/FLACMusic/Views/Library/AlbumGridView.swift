import SwiftUI
import GRDB

struct AlbumGridView: View {
    @Binding var selectedAlbum: Album?
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @State private var albums: [AlbumInfo] = []

    private let db = DatabaseManager.shared
    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            if albums.isEmpty {
                ContentUnavailableView {
                    Label("No Albums", systemImage: "music.note")
                } description: {
                    Text("Import a folder to get started")
                }
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(albums) { albumInfo in
                        AlbumCard(albumInfo: albumInfo)
                            .onTapGesture {
                                selectedAlbum = albumInfo.album
                            }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Albums")
        .task {
            loadAlbums()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadAlbums()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func loadAlbums() {
        do {
            albums = try db.dbQueue.read { db in
                try LibraryQueries.allAlbums(in: db)
            }
        } catch {
            print("Failed to load albums: \(error)")
        }
    }
}

private struct AlbumCard: View {
    let albumInfo: AlbumInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtView(album: albumInfo.album, size: 170)

            Text(albumInfo.album.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            if let artist = albumInfo.artist {
                Text(artist.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 170)
    }
}
