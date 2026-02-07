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
    @State private var forwardAlbum: Album?
    @State private var searchText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                SidebarView(selection: $selectedSection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
            } detail: {
                detailContent
                    .safeAreaPadding(.bottom, playerState.currentTrack != nil ? 90 : 0)
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
            .onChange(of: selectedSection) {
                if selectedAlbum != nil {
                    selectedAlbum = nil
                    forwardAlbum = nil
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        navigateBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(selectedAlbum == nil)

                    Button {
                        navigateForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(forwardAlbum == nil)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Import Folder", systemImage: "folder.badge.plus") {
                        importFolder()
                    }
                    .disabled(libraryManager.isImporting)
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
                .padding(.bottom, playerState.currentTrack != nil ? 100 : 20)
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
                .padding(.bottom, playerState.currentTrack != nil ? 130 : 50)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let album = selectedAlbum {
            AlbumDetailView(album: album)
        } else {
            sectionContent
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .albums:
            AlbumGridView(selectedAlbum: $selectedAlbum)
        case .artists:
            ArtistListView(selectedAlbum: $selectedAlbum)
        case .songs:
            SongListView()
        case .recentlyAdded:
            RecentlyAddedView(selectedAlbum: $selectedAlbum)
        case .playlist(let playlist):
            PlaylistDetailView(playlist: playlist)
        case .search:
            SearchResultsView(searchText: $searchText, selectedAlbum: $selectedAlbum)
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

    private func navigateBack() {
        guard selectedAlbum != nil else { return }
        forwardAlbum = selectedAlbum
        selectedAlbum = nil
    }

    private func navigateForward() {
        guard let album = forwardAlbum else { return }
        selectedAlbum = album
        forwardAlbum = nil
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
