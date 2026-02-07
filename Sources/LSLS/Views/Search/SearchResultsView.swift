import SwiftUI
import GRDB

struct SearchResultsView: View {
    @Binding var searchText: String
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(SyncManager.self) private var syncManager
    @State private var tracks: [TrackInfo] = []
    @State private var albums: [AlbumInfo] = []
    @State private var artists: [Artist] = []
    @Binding var selectedAlbum: Album?
    @State private var playlists: [Playlist] = []
    @State private var trackToEdit: TrackInfo? = nil
    @State private var trackToDelete: TrackInfo? = nil

    private let db = DatabaseManager.shared

    var body: some View {
        searchContent
        .background(colors.background)
        .onChange(of: searchText) { _, newValue in
            performSearch(newValue)
        }
        .task {
            loadPlaylists()
        }
        .sheet(item: $trackToEdit) { trackInfo in
            TrackEditView(trackInfo: trackInfo) {
                performSearch(searchText)
            }
        }
        .alert("Delete Track?", isPresented: Binding(
            get: { trackToDelete != nil },
            set: { if !$0 { trackToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { trackToDelete = nil }
            Button("Delete", role: .destructive) {
                if let track = trackToDelete {
                    deleteTrack(track)
                    trackToDelete = nil
                }
            }
        } message: {
            Text("This will remove \"\(trackToDelete?.track.title ?? "")\" from your library and all playlists.")
        }
    }

    private var searchContent: some View {
        ScrollView {
            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("Search", systemImage: "magnifyingglass")
                } description: {
                    Text("Search for songs, albums, and artists")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else if tracks.isEmpty && albums.isEmpty && artists.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No results for \"\(searchText)\"")
                }
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 100)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !artists.isEmpty {
                        Section {
                            ForEach(artists) { artist in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(colors.accentSubtle)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "music.mic")
                                            .foregroundStyle(colors.accent)
                                    }
                                    Text(artist.name)
                                        .foregroundStyle(colors.textPrimary)
                                }
                                .padding(.horizontal, 24)
                            }
                        } header: {
                            Text("Artists")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }

                    if !albums.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(albums) { albumInfo in
                                        VStack(alignment: .leading, spacing: 6) {
                                            AlbumArtView(album: albumInfo.album, size: 140)

                                            Text(albumInfo.album.title)
                                                .font(.system(size: theme.typography.captionSize, weight: .medium))
                                                .foregroundStyle(colors.textPrimary)
                                                .lineLimit(1)

                                            if let artist = albumInfo.artist {
                                                Text(artist.name)
                                                    .font(.system(size: theme.typography.smallCaptionSize))
                                                    .foregroundStyle(colors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(width: 140)
                                        .onTapGesture {
                                            selectedAlbum = albumInfo.album
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        } header: {
                            Text("Albums")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }

                    if !tracks.isEmpty {
                        Section {
                            VStack(spacing: 0) {
                                ForEach(tracks) { trackInfo in
                                    TrackRow(
                                        trackInfo: trackInfo,
                                        isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id,
                                        playlists: playlists
                                    ) {
                                        playerState.play(track: trackInfo, fromQueue: tracks)
                                    } onAddToQueue: {
                                        playerState.addToQueueEnd(trackInfo)
                                    } onAddToPlaylist: { playlist in
                                        addTrackToPlaylist(trackInfo, playlist: playlist)
                                    } onDelete: {
                                        trackToDelete = trackInfo
                                    } onEdit: {
                                        trackToEdit = trackInfo
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        } header: {
                            Text("Songs")
                                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                                .foregroundStyle(colors.textPrimary)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Search")
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            tracks = []
            albums = []
            artists = []
            return
        }
        do {
            let results = try db.dbQueue.read { db in
                try LibraryQueries.search(query, in: db)
            }
            tracks = results.tracks
            albums = results.albums
            artists = results.artists
        } catch {
            print("Search failed: \(error)")
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

    private func addTrackToPlaylist(_ trackInfo: TrackInfo, playlist: Playlist) {
        guard let trackId = trackInfo.track.id, let playlistId = playlist.id else { return }
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: dbConn)
            }
        } catch {
            print("Failed to add track to playlist: \(error)")
        }
    }

    private func deleteTrack(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        if playerState.currentTrack?.track.id == trackId {
            playerState.playNext()
        }
        do {
            try db.dbQueue.write { dbConn in
                try LibraryQueries.deleteTrack(trackId, in: dbConn)
            }
            performSearch(searchText)
        } catch {
            print("Failed to delete track: \(error)")
        }
    }
}
