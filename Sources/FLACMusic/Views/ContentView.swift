import SwiftUI

struct ContentView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(LibraryManager.self) private var libraryManager
    @State private var selectedSection: SidebarSection? = .albums
    @State private var selectedAlbum: Album?
    @State private var selectedArtist: Artist?
    @State private var searchText = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView {
                SidebarView(selection: $selectedSection)
            } detail: {
                Group {
                    switch selectedSection {
                    case .albums:
                        AlbumGridView(selectedAlbum: $selectedAlbum)
                    case .artists:
                        ArtistListView(selectedArtist: $selectedArtist)
                    case .songs:
                        SongListView()
                    case .recentlyAdded:
                        RecentlyAddedView()
                    case .playlist(let playlist):
                        PlaylistDetailView(playlist: playlist)
                    case .search:
                        SearchResultsView(searchText: $searchText)
                    case .none:
                        Text("Select a section")
                            .foregroundStyle(.secondary)
                    }
                }
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
            }

            if libraryManager.isImporting {
                VStack(spacing: 6) {
                    ProgressView(value: libraryManager.importProgress)
                    Text(libraryManager.importStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, playerState.currentTrack != nil ? 80 : 20)
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
