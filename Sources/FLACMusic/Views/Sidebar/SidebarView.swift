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
    @State private var playlists: [Playlist] = []
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""

    private let db = DatabaseManager.shared

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("Albums", systemImage: "square.grid.2x2")
                    .tag(SidebarSection.albums)
                Label("Artists", systemImage: "music.mic")
                    .tag(SidebarSection.artists)
                Label("Songs", systemImage: "music.note")
                    .tag(SidebarSection.songs)
                Label("Recently Added", systemImage: "clock")
                    .tag(SidebarSection.recentlyAdded)
            }

            Section("Playlists") {
                ForEach(playlists) { playlist in
                    Label(playlist.name, systemImage: "music.note.list")
                        .tag(SidebarSection.playlist(playlist))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                deletePlaylist(playlist)
                            }
                        }
                }

                Button {
                    showNewPlaylist = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
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
