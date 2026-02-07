import SwiftUI
import GRDB

struct AlbumGridView: View {
    @Binding var selectedAlbum: Album?
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var albums: [AlbumInfo] = []

    private let db = DatabaseManager.shared

    private var columns: [GridItem] {
        [GridItem(.adaptive(
            minimum: theme.spacing.gridItemSize,
            maximum: theme.spacing.gridItemSize + 30
        ), spacing: theme.spacing.gridSpacing)]
    }

    var body: some View {
        ScrollView {
            if albums.isEmpty {
                ContentUnavailableView {
                    Label("No Albums", systemImage: "music.note")
                } description: {
                    Text("Import a folder to get started")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: theme.spacing.sectionSpacing) {
                    ForEach(albums) { albumInfo in
                        AlbumCard(albumInfo: albumInfo) {
                            selectedAlbum = albumInfo.album
                        }
                        .contextMenu {
                            if let albumId = albumInfo.album.id {
                                if syncManager.isAlbumInSyncList(albumId) {
                                    Button("Remove Album from Sync List", role: .destructive) {
                                        if let item = syncManager.syncItems.first(where: { $0.itemType == .album && $0.albumId == albumId }) {
                                            syncManager.removeSyncItem(item)
                                        }
                                    }
                                } else {
                                    Button("Add Album to Sync List") {
                                        syncManager.addAlbum(albumId)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(theme.spacing.contentPadding)
            }
        }
        .background(colors.background)
        .navigationTitle("Albums")
        .task {
            loadAlbums()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadAlbums()
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
