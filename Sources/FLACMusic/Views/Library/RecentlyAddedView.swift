import SwiftUI
import GRDB

struct RecentlyAddedView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbum: Album?

    private let db = DatabaseManager.shared
    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            if albums.isEmpty {
                ContentUnavailableView {
                    Label("Nothing Here Yet", systemImage: "clock")
                } description: {
                    Text("Recently imported albums will appear here")
                }
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(albums) { albumInfo in
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
                        .onTapGesture {
                            selectedAlbum = albumInfo.album
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Recently Added")
        .task {
            loadRecent()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadRecent()
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environment(playerState)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func loadRecent() {
        do {
            albums = try db.dbQueue.read { db in
                try LibraryQueries.recentlyAdded(in: db)
            }
        } catch {
            print("Failed to load recent: \(error)")
        }
    }
}
