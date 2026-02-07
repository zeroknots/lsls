import SwiftUI
import GRDB

struct RecentlyAddedView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var albums: [AlbumInfo] = []
    @Binding var selectedAlbum: Album?
    @State private var albumToDelete: AlbumInfo? = nil

    private let db = DatabaseManager.shared

    private var columns: [GridItem] {
        [GridItem(.adaptive(
            minimum: theme.spacing.gridItemSize,
            maximum: theme.spacing.gridItemSize + 30
        ), spacing: theme.spacing.gridSpacing)]
    }

    var body: some View {
        recentGrid
        .background(colors.background)
        .task {
            loadRecent()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadRecent()
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

    private var recentGrid: some View {
        ScrollView {
            if albums.isEmpty {
                ContentUnavailableView {
                    Label("Nothing Here Yet", systemImage: "clock")
                } description: {
                    Text("Recently imported albums will appear here")
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
        .navigationTitle("Recently Added")
    }

    private func deleteAlbum(_ albumId: Int64) {
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.deleteAlbum(albumId, in: dbConn)
            }
            loadRecent()
        } catch {
            print("Failed to delete album: \(error)")
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
