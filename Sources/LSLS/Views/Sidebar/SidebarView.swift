import SwiftUI
import GRDB

enum SidebarSection: Hashable {
    case albums
    case artists
    case songs
    case recentlyAdded
    case search
    case playlist(Playlist)
    case smartPlaylist(SmartPlaylist)
    case syncList
    case plexAlbums
    case plexArtists
    case plexSettings
}

struct SidebarView: View {
    @Binding var selection: SidebarSection?
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(LibraryManager.self) private var libraryManager
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var playlists: [Playlist] = []
    @State private var smartPlaylists: [SmartPlaylist] = []
    @State private var showNewPlaylist = false
    @State private var showNewSmartPlaylist = false
    @State private var newPlaylistName = ""

    private let db = DatabaseManager.shared

    var body: some View {
        List(selection: $selection) {
            Section {
                sidebarRow("Albums", icon: "square.grid.2x2", tag: .albums)
                sidebarRow("Artists", icon: "music.mic", tag: .artists)
                sidebarRow("Songs", icon: "music.note", tag: .songs)
                sidebarRow("Recently Added", icon: "clock", tag: .recentlyAdded)
            } header: {
                Text("Library")
                    .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                    .foregroundStyle(colors.textTertiary)
                    .textCase(nil)
            }

            Section {
                Label {
                    HStack {
                        Text("Sync List")
                        Spacer()
                        if !syncManager.syncItems.isEmpty {
                            Text("\(syncManager.syncItems.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        Circle()
                            .fill(syncManager.isDeviceConnected ? .green : .gray)
                            .frame(width: 8, height: 8)
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .tag(SidebarSection.syncList)
                .dropDestination(for: LibraryDragItem.self) { items, _ in
                    handleSyncDrop(items)
                    return true
                }
            } header: {
                Text("DAP")
                    .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                    .foregroundStyle(colors.textTertiary)
                    .textCase(nil)
            }

            Section {
                if plexState.isConnected {
                    sidebarRow("Albums", icon: "square.grid.2x2", tag: .plexAlbums)
                    sidebarRow("Artists", icon: "music.mic", tag: .plexArtists)
                }
                sidebarRow(plexState.isConnected ? "Settings" : "Connect", icon: "server.rack", tag: .plexSettings)
            } header: {
                Text("Plex")
                    .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                    .foregroundStyle(colors.textTertiary)
                    .textCase(nil)
            }

            Section {
                ForEach(playlists) { playlist in
                    sidebarRow(playlist.name, icon: "music.note.list", tag: .playlist(playlist))
                        .dropDestination(for: LibraryDragItem.self) { items, _ in
                            handlePlaylistDrop(items, playlist: playlist)
                            return true
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deletePlaylist(playlist)
                            }
                        }
                }

                ForEach(smartPlaylists) { sp in
                    sidebarRow(sp.name, icon: "wand.and.stars", tag: .smartPlaylist(sp))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deleteSmartPlaylist(sp)
                            }
                        }
                }

                Menu {
                    Button("New Playlist") {
                        showNewPlaylist = true
                    }
                    Button("New Smart Playlist") {
                        showNewSmartPlaylist = true
                    }
                } label: {
                    Label {
                        Text("New Playlist")
                            .foregroundStyle(colors.textTertiary)
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundStyle(colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Playlists")
                    .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                    .foregroundStyle(colors.textTertiary)
                    .textCase(nil)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if libraryManager.isImporting || syncManager.isSyncing {
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 8) {
                        if libraryManager.isImporting {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.caption)
                                        .foregroundStyle(colors.accent)
                                    Text("Importing...")
                                        .font(.system(size: theme.typography.captionSize, weight: .medium))
                                        .foregroundStyle(colors.textPrimary)
                                }
                                ProgressView(value: libraryManager.importProgress)
                                    .tint(colors.accent)
                                Text(libraryManager.importStatus)
                                    .font(.system(size: theme.typography.smallCaptionSize))
                                    .foregroundStyle(colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        if syncManager.isSyncing {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                        .foregroundStyle(colors.accent)
                                    Text("Syncing to DAP...")
                                        .font(.system(size: theme.typography.captionSize, weight: .medium))
                                        .foregroundStyle(colors.textPrimary)
                                }
                                ProgressView(value: syncManager.syncProgress)
                                    .tint(colors.accent)
                                Text(syncManager.syncStatus)
                                    .font(.system(size: theme.typography.smallCaptionSize))
                                    .foregroundStyle(colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle("LSLS")
        .task {
            loadPlaylists()
            loadSmartPlaylists()
        }
        .alert("New Playlist", isPresented: $showNewPlaylist) {
            TextField("Playlist name", text: $newPlaylistName)
            Button("Cancel", role: .cancel) {
                newPlaylistName = ""
            }
            Button("Create") {
                createPlaylist()
            }
        }
        .sheet(isPresented: $showNewSmartPlaylist) {
            SmartPlaylistEditorView(smartPlaylist: nil) {
                loadSmartPlaylists()
            }
        }
    }

    private func sidebarRow(_ title: String, icon: String, tag: SidebarSection) -> some View {
        Label {
            Text(title)
                .foregroundStyle(colors.textPrimary)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: theme.typography.captionSize))
                .foregroundStyle(colors.accent)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(colors.accentSubtle)
                )
        }
        .tag(tag)
    }

    private func loadPlaylists() {
        do {
            playlists = try db.dbQueue.read { db in
                try LibraryQueries.allPlaylists(in: db)
            }
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    private func createPlaylist() {
        guard !newPlaylistName.isEmpty else { return }
        do {
            try db.dbQueue.write { dbConn in
                var playlist = Playlist(name: newPlaylistName)
                try playlist.insert(dbConn)
            }
            newPlaylistName = ""
            loadPlaylists()
        } catch {
            print("Failed to create playlist: \(error)")
        }
    }

    private func deletePlaylist(_ playlist: Playlist) {
        do {
            try db.dbQueue.write { dbConn in
                _ = try playlist.delete(dbConn)
            }
            loadPlaylists()
        } catch {
            print("Failed to delete playlist: \(error)")
        }
    }

    private func loadSmartPlaylists() {
        do {
            smartPlaylists = try db.dbQueue.read { db in
                try LibraryQueries.allSmartPlaylists(in: db)
            }
        } catch {
            print("Failed to load smart playlists: \(error)")
        }
    }

    private func deleteSmartPlaylist(_ sp: SmartPlaylist) {
        guard let id = sp.id else { return }
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.deleteSmartPlaylist(id, in: dbConn)
            }
            loadSmartPlaylists()
        } catch {
            print("Failed to delete smart playlist: \(error)")
        }
    }

    private func handleSyncDrop(_ items: [LibraryDragItem]) {
        for item in items {
            switch item {
            case .track(let trackInfo):
                if let trackId = trackInfo.track.id {
                    syncManager.addTrack(trackId)
                }
            case .album(let albumInfo):
                if let albumId = albumInfo.album.id {
                    syncManager.addAlbum(albumId)
                }
            case .artist(let artist):
                if let artistId = artist.id {
                    syncManager.addArtist(artistId)
                }
            }
        }
    }

    private func handlePlaylistDrop(_ items: [LibraryDragItem], playlist: Playlist) {
        guard let playlistId = playlist.id else { return }
        for item in items {
            switch item {
            case .track(let trackInfo):
                if let trackId = trackInfo.track.id {
                    try? db.dbQueue.write { dbConn in
                        try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
                    }
                }
            case .album(let albumInfo):
                if let albumId = albumInfo.album.id {
                    try? db.dbQueue.write { dbConn in
                        let tracks = try LibraryQueries.tracksForAlbum(albumId, in: dbConn)
                        for track in tracks {
                            if let trackId = track.track.id {
                                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
                            }
                        }
                    }
                }
            case .artist(let artist):
                if let artistId = artist.id {
                    try? db.dbQueue.write { dbConn in
                        let tracks = try LibraryQueries.tracksForArtist(artistId, in: dbConn)
                        for track in tracks {
                            if let trackId = track.track.id {
                                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
                            }
                        }
                    }
                }
            }
        }
    }
}
