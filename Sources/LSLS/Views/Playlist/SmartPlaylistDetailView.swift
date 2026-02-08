import SwiftUI
import GRDB

struct SmartPlaylistDetailView: View {
    let smartPlaylist: SmartPlaylist
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var tracks: [TrackInfo] = []
    @State private var playlists: [Playlist] = []
    @State private var rules: [SmartPlaylistRule] = []
    @State private var favorites: Set<Int64> = []
    @State private var showEditor = false

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.shapes.albumArtRadius)
                        .fill(
                            LinearGradient(
                                colors: [colors.accent, colors.accentSubtle],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(smartPlaylist.name)
                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                        .foregroundStyle(colors.textPrimary)

                    Text("\(tracks.count) songs")
                        .foregroundStyle(colors.textSecondary)

                    if !tracks.isEmpty {
                        HStack(spacing: 12) {
                            Button("Play All") {
                                if let first = tracks.first {
                                    playerState.play(track: first, fromQueue: tracks)
                                }
                            }
                            .buttonStyle(AccentFilledButtonStyle())

                            Button("Shuffle") {
                                if let random = tracks.randomElement() {
                                    playerState.shuffleEnabled = true
                                    playerState.play(track: random, fromQueue: tracks)
                                }
                            }
                            .buttonStyle(AccentOutlineButtonStyle())
                        }
                    }

                    Button("Edit Rules") {
                        showEditor = true
                    }
                    .buttonStyle(AccentOutlineButtonStyle())
                }

                Spacer()
            }
            .padding(24)

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

            // Track list
            if tracks.isEmpty {
                ContentUnavailableView {
                    Label("No Matching Songs", systemImage: "wand.and.stars")
                } description: {
                    Text("Edit rules to match songs")
                }
                .foregroundStyle(colors.textSecondary)
            } else {
                List {
                    ForEach(tracks) { trackInfo in
                        trackRow(for: trackInfo)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(colors.background)
            }
        }
        .background(colors.background)
        .navigationTitle(smartPlaylist.name)
        .task {
            loadRulesAndTracks()
            loadPlaylists()
            loadFavorites()
        }
        .sheet(isPresented: $showEditor) {
            SmartPlaylistEditorView(smartPlaylist: smartPlaylist) {
                loadRulesAndTracks()
            }
        }
    }

    @ViewBuilder
    private func trackRow(for trackInfo: TrackInfo) -> some View {
        TrackRow(
            trackInfo: trackInfo,
            isPlaying: playerState.currentTrack?.track.id == trackInfo.track.id,
            isFavorite: favorites.contains(trackInfo.track.id ?? -1),
            playlists: playlists
        ) {
            playerState.play(track: trackInfo, fromQueue: tracks)
        } onAddToQueue: {
            playerState.addToQueueEnd(trackInfo)
        } onAddToPlaylist: { targetPlaylist in
            addTrackToPlaylist(trackInfo, playlist: targetPlaylist)
        } onFavoriteToggle: {
            toggleFavorite(trackInfo)
        }
    }

    private func loadRulesAndTracks() {
        guard let smartPlaylistId = smartPlaylist.id else { return }
        do {
            try db.dbPool.read { db in
                rules = try LibraryQueries.rulesForSmartPlaylist(smartPlaylistId, in: db)
                tracks = try LibraryQueries.smartPlaylistTracks(rules, in: db)
            }
            loadFavorites()
        } catch {
            print("Failed to load smart playlist rules and tracks: \(error)")
        }
    }

    private func loadPlaylists() {
        do {
            playlists = try db.dbPool.read { db in
                try LibraryQueries.allPlaylists(in: db)
            }
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    private func loadFavorites() {
        do {
            favorites = try db.dbPool.read { db in
                var favoriteSet = Set<Int64>()
                for trackInfo in tracks {
                    if let trackId = trackInfo.track.id {
                        if try LibraryQueries.isFavorite(trackId: trackId, in: db) {
                            favoriteSet.insert(trackId)
                        }
                    }
                }
                return favoriteSet
            }
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }

    private func toggleFavorite(_ trackInfo: TrackInfo) {
        guard let trackId = trackInfo.track.id else { return }
        do {
            try db.dbPool.write { db in
                try LibraryQueries.toggleFavorite(trackId: trackId, in: db)
            }
            if favorites.contains(trackId) {
                favorites.remove(trackId)
            } else {
                favorites.insert(trackId)
            }
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }

    private func addTrackToPlaylist(_ trackInfo: TrackInfo, playlist: Playlist) {
        guard let trackId = trackInfo.track.id, let playlistId = playlist.id else { return }
        do {
            try db.dbPool.write { db in
                try LibraryQueries.addTrackToPlaylist(trackId: trackId, playlistId: playlistId, in: db)
            }
        } catch {
            print("Failed to add track to playlist: \(error)")
        }
    }
}
