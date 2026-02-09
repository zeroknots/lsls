import SwiftUI
import GRDB

struct AlbumGridView: View {
    @Binding var selectedAlbum: Album?
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @Environment(VimNavigation.self) private var vimNav
    @State private var albums: [AlbumInfo] = []
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
        ScrollViewReader { proxy in
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
                        ForEach(Array(albums.enumerated()), id: \.element.id) { index, albumInfo in
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
                            .overlay {
                                if vimNav.isActive && vimNav.focusZone == .content && index == vimNav.contentIndex {
                                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                                        .stroke(colors.accent, lineWidth: 2.5)
                                        .allowsHitTesting(false)
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
            .onChange(of: vimNav.enterTrigger) {
                guard vimNav.isActive, vimNav.focusZone == .content else { return }
                guard vimNav.contentIndex >= 0 && vimNav.contentIndex < albums.count else { return }
                selectedAlbum = albums[vimNav.contentIndex].album
            }
            .onChange(of: vimNav.contentIndex) { _, newIndex in
                guard vimNav.isActive, vimNav.focusZone == .content else { return }
                if newIndex >= 0 && newIndex < albums.count {
                    withAnimation { proxy.scrollTo(albums[newIndex].id, anchor: .center) }
                }
            }
        }
        .background(
            GeometryReader { geo in
                colors.background
                    .onAppear { updateGridColumns(containerWidth: geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in updateGridColumns(containerWidth: w) }
            }
        )
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
        .navigationTitle("Albums")
        .task {
            loadAlbums()
        }
        .onChange(of: libraryManager.lastImportDate) {
            loadAlbums()
        }
        .onChange(of: selectedAlbumIds) {
            vimNav.hasActiveSelection = !selectedAlbumIds.isEmpty
        }
        .sheet(isPresented: $showMergeSheet) {
            MergeAlbumsView(selectedAlbums: selectedAlbumInfos) {
                selectedAlbumIds.removeAll()
                loadAlbums()
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

    private func deleteSelectedAlbums() {
        do {
            try db.dbPool.write { dbConn in
                for albumId in selectedAlbumIds {
                    try LibraryQueries.deleteAlbum(albumId, in: dbConn)
                }
            }
            selectedAlbumIds.removeAll()
            loadAlbums()
        } catch {
            print("Failed to delete albums: \(error)")
        }
    }

    private func loadAlbums() {
        do {
            albums = try db.dbPool.read { db in
                try LibraryQueries.allAlbums(in: db)
            }
            vimNav.contentItemCount = albums.count
            vimNav.isGridMode = true
        } catch {
            print("Failed to load albums: \(error)")
        }
    }

    private func updateGridColumns(containerWidth: CGFloat) {
        let itemSize = theme.spacing.gridItemSize
        let spacing = theme.spacing.gridSpacing
        let padding = theme.spacing.contentPadding * 2
        let available = containerWidth - padding
        let cols = max(1, Int((available + spacing) / (itemSize + spacing)))
        vimNav.gridColumns = cols
    }
}
