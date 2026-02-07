import SwiftUI

struct ContentView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var selectedSection: SidebarSection? = .albums
    @State private var selectedAlbum: Album?
    @State private var searchText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                SidebarView(selection: $selectedSection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
            } detail: {
                Group {
                    switch selectedSection {
                    case .albums:
                        AlbumGridView(selectedAlbum: $selectedAlbum)
                    case .artists:
                        ArtistListView()
                    case .songs:
                        SongListView()
                    case .recentlyAdded:
                        RecentlyAddedView()
                    case .playlist(let playlist):
                        PlaylistDetailView(playlist: playlist)
                    case .search:
                        SearchResultsView(searchText: $searchText)
                    case .syncList:
                        SyncListView()
                    case .plexAlbums:
                        PlexAlbumGridView()
                    case .plexArtists:
                        PlexArtistListView()
                    case .plexSettings:
                        PlexSettingsView()
                    case .none:
                        Text("Select a section")
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                .background(colors.background)
            }
            .searchable(text: $searchText, prompt: "Search music")
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    selectedSection = .search
                } else if selectedSection == .search {
                    selectedSection = .albums
                }
            }

            if playerState.currentTrack != nil {
                NowPlayingBar()
                    .environment(playerState)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if libraryManager.isImporting {
                VStack(spacing: 6) {
                    ProgressView(value: libraryManager.importProgress)
                        .tint(colors.accent)
                    Text(libraryManager.importStatus)
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(colors.backgroundTertiary.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
                .shadow(color: .black.opacity(0.2), radius: 8)
                .padding(.bottom, playerState.currentTrack != nil ? 80 : 20)
            }

            if syncManager.isSyncing, selectedSection != .syncList {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("Syncing to Rockbox...")
                            .font(.caption.weight(.medium))
                    }
                    ProgressView(value: syncManager.syncProgress)
                    Text(syncManager.syncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, playerState.currentTrack != nil ? 110 : 50)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import Folder", systemImage: "folder.badge.plus") {
                    importFolder()
                }
                .disabled(libraryManager.isImporting)
            }
        }
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select folders containing music files"

        if panel.runModal() == .OK {
            Task {
                for url in panel.urls {
                    await libraryManager.importFolder(url)
                }
            }
        }
    }
}
