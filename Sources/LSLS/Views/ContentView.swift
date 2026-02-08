import SwiftUI

struct ContentView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(NavigationRequest.self) private var navigationRequest
    @Environment(\.themeColors) private var colors
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
            .inspector(isPresented: Bindable(playerState).isQueueVisible) {
                QueueSidebarView()
                    .inspectorColumnWidth(min: 250, ideal: 280, max: 350)
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
                    Button {
                        withAnimation {
                            playerState.isQueueVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(playerState.isQueueVisible ? colors.accent : colors.textSecondary)
                    }
                    .help("Toggle Queue")
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

        }
        .overlay {
            if navigationRequest.isCommandPaletteVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        navigationRequest.isCommandPaletteVisible = false
                    }

                VStack {
                    Spacer().frame(height: 100)

                    CommandPaletteView(
                        isPresented: Bindable(navigationRequest).isCommandPaletteVisible,
                        onNavigateToArtist: { artist in
                            selectedSection = .artists
                            navigationRequest.requestNavigation(toArtistId: artist.id!, trackId: nil)
                        },
                        onNavigateToAlbum: { album in
                            selectedAlbum = album
                        },
                        onNavigateToTrack: { trackInfo in
                            if let artistId = trackInfo.artist?.id {
                                selectedSection = .artists
                                navigationRequest.requestNavigation(toArtistId: artistId, trackId: trackInfo.track.id)
                            }
                        },
                        onPlayTrack: { trackInfo in
                            playerState.play(track: trackInfo)
                        }
                    )

                    Spacer()
                }
            } else if navigationRequest.isPlaylistPaletteVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        navigationRequest.isPlaylistPaletteVisible = false
                    }

                VStack {
                    Spacer().frame(height: 100)

                    PlaylistPaletteView(
                        isPresented: Bindable(navigationRequest).isPlaylistPaletteVisible,
                        onSelect: { item in
                            openPlaylistAndPlay(item)
                        }
                    )

                    Spacer()
                }
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
        case .smartPlaylist(let sp):
            SmartPlaylistDetailView(smartPlaylist: sp)
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

    private func openPlaylistAndPlay(_ item: PlaylistPaletteItem) {
        let db = DatabaseManager.shared
        switch item {
        case .playlist(let playlist):
            selectedSection = .playlist(playlist)
            guard let playlistId = playlist.id else { return }
            if let tracks = try? db.dbPool.read({ try LibraryQueries.playlistTracks(playlistId, in: $0) }),
               let first = tracks.first {
                playerState.play(track: first, fromQueue: tracks)
            }
        case .smartPlaylist(let sp):
            selectedSection = .smartPlaylist(sp)
            guard let spId = sp.id else { return }
            if let rules = try? db.dbPool.read({ try LibraryQueries.rulesForSmartPlaylist(spId, in: $0) }),
               let tracks = try? db.dbPool.read({ try LibraryQueries.smartPlaylistTracks(rules, in: $0) }),
               let first = tracks.first {
                playerState.play(track: first, fromQueue: tracks)
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
