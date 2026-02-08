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
    @State private var selectedAlbumIds: Set<Int64> = []
    @State private var showMergeSheet = false

    private let db = DatabaseManager.shared

    private var columns: [GridItem] {
        [GridItem(.adaptive(
            minimum: theme.spacing.gridItemSize,
            maximum: theme.spacing.gridItemSize + 30
        ), spacing: theme.spacing.gridSpacing)]
    }

    private var selectedAlbumInfos: [AlbumInfo] {
        albums.filter { albumInfo in
            guard let id = albumInfo.album.id else { return false }
            return selectedAlbumIds.contains(id)
        }
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
        .sheet(isPresented: $showMergeSheet) {
            MergeAlbumsView(selectedAlbums: selectedAlbumInfos) {
                selectedAlbumIds.removeAll()
                loadRecent()
            }
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
                        let albumId = albumInfo.album.id ?? -1
                        let isInSelection = selectedAlbumIds.contains(albumId)

                        AlbumCard(
                            albumInfo: albumInfo,
                            isSelected: isInSelection
                        ) { withCommand in
                            if withCommand {
                                if selectedAlbumIds.contains(albumId) {
                                    selectedAlbumIds.remove(albumId)
                                } else {
                                    selectedAlbumIds.insert(albumId)
                                }
                            } else {
                                selectedAlbumIds.removeAll()
                                selectedAlbum = albumInfo.album
                            }
                        }
                        .contextMenu {
                            if isInSelection && selectedAlbumIds.count >= 2 {
                                Button("Merge...") {
                                    showMergeSheet = true
                                }

                                Divider()

                                Button("Delete \(selectedAlbumIds.count) Albums", role: .destructive) {
                                    deleteSelectedAlbums()
                                }
                            } else {
                                if let aid = albumInfo.album.id {
                                    if syncManager.isAlbumInSyncList(aid) {
                                        Button("Remove Album from Sync List", role: .destructive) {
                                            if let item = syncManager.syncItems.first(where: { $0.itemType == .album && $0.albumId == aid }) {
                                                syncManager.removeSyncItem(item)
                                            }
                                        }
                                    } else {
                                        Button("Add Album to Sync List") {
                                            syncManager.addAlbum(aid)
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
                }
                .padding(theme.spacing.contentPadding)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedAlbumIds.removeAll()
        }
        .onKeyPress(.escape) {
            if !selectedAlbumIds.isEmpty {
                selectedAlbumIds.removeAll()
                return .handled
            }
            return .ignored
        }
        .navigationTitle("Recently Added")
    }

    private func deleteAlbum(_ albumId: Int64) {
        do {
            try db.dbPool.write { dbConn in
                try LibraryQueries.deleteAlbum(albumId, in: dbConn)
            }
            loadRecent()
        } catch {
            print("Failed to delete album: \(error)")
        }
    }

    private func deleteSelectedAlbums() {
        do {
            try db.dbPool.write { dbConn in
                for albumId in selectedAlbumIds {
                    try LibraryQueries.deleteAlbum(albumId, in: dbConn)
                }
            }
            selectedAlbumIds.removeAll()
            loadRecent()
        } catch {
            print("Failed to delete albums: \(error)")
        }
    }

    private func loadRecent() {
        do {
            albums = try db.dbPool.read { db in
                try LibraryQueries.recentlyAdded(in: db)
            }
        } catch {
            print("Failed to load recent: \(error)")
        }
    }
}
