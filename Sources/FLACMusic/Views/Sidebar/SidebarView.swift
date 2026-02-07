import SwiftUI
import GRDB

enum SidebarSection: Hashable {
    case albums
    case artists
    case songs
    case recentlyAdded
    case search
    case playlist(Playlist)
}

struct SidebarView: View {
    @Binding var selection: SidebarSection?
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
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
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle("FLACMusic")
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
