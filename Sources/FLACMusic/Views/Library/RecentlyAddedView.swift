import SwiftUI
import GRDB

struct RecentlyAddedView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbum: Album?

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
                    }
                }
                .padding(theme.spacing.contentPadding)
            }
        }
        .background(colors.background)
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
