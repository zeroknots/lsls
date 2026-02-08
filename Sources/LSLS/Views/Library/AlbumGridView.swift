import SwiftUI
import GRDB

struct AlbumGridView: View {
    @Binding var selectedAlbum: Album?
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var albums: [AlbumInfo] = []
    @State private var albumToDelete: AlbumInfo? = nil

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

                                Divider()

                                Button("Delete Album", role: .destructive) {
                                    albumToDelete = albumInfo
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
        .alert("Delete Album?", isPresented: Binding(
            get: { albumToDelete != nil },
            set: { if !$0 { albumToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { albumToDelete = nil }
            Button("Delete", role: .destructive) {
                if let albumInfo = albumToDelete, let albumId = albumInfo.album.id {
                    deleteAlbum(albumId)
                    albumToDelete = nil
                }
            }
        } message: {
            Text("This will delete \"\(albumToDelete?.album.title ?? "")\" and all its tracks.")
        }
    }

    private func deleteAlbum(_ albumId: Int64) {
        do {
            try db.dbPool.write { dbConn in
                try LibraryQueries.deleteAlbum(albumId, in: dbConn)
            }
            loadAlbums()
        } catch {
            print("Failed to delete album: \(error)")
        }
    }

    private func loadAlbums() {
        do {
            albums = try db.dbPool.read { db in
                try LibraryQueries.allAlbums(in: db)
            }
        } catch {
            print("Failed to load albums: \(error)")
        }
    }
}
