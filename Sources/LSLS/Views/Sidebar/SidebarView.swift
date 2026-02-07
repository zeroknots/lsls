import SwiftUI
import GRDB

enum SidebarSection: Hashable {
    case albums
    case artists
    case songs
    case recentlyAdded
    case search
    case playlist(Playlist)
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
    @State private var showNewPlaylist = false
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
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deletePlaylist(playlist)
                            }
                        }
                }

                Button {
                    showNewPlaylist = true
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
}
