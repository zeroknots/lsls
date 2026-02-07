import Foundation

@MainActor
@Observable
final class PlexLibraryBrowser {
    private let plexState: PlexConnectionState

    var artists: [PlexArtist] = []
    var albums: [PlexAlbum] = []
    var isLoading = false
    var error: String?

    init(plexState: PlexConnectionState) {
        self.plexState = plexState
    }

    private var server: PlexServer? { plexState.selectedServer }
    private var sectionKey: String? { plexState.selectedLibrary?.key }

    func fetchArtists() async {
        guard let server, let sectionKey else { return }
        isLoading = true
        error = nil
        do {
            artists = try await plexState.apiClient.getArtists(server: server, sectionKey: sectionKey)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchAlbums() async {
        guard let server, let sectionKey else { return }
        isLoading = true
        error = nil
        do {
            albums = try await plexState.apiClient.getAlbums(server: server, sectionKey: sectionKey)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchAlbumsForArtist(_ artist: PlexArtist) async -> [PlexAlbum] {
        guard let server else { return [] }
        do {
            return try await plexState.apiClient.getAlbumsForArtist(server: server, artistRatingKey: artist.ratingKey)
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    func fetchTracksForAlbum(_ album: PlexAlbum) async -> [PlexTrack] {
        guard let server else { return [] }
        do {
            return try await plexState.apiClient.getTracksForAlbum(server: server, albumRatingKey: album.ratingKey)
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // Convert PlexTrack to TrackInfo for playback via PlayerState
    func makeTrackInfo(from plexTrack: PlexTrack, album: PlexAlbum? = nil) -> TrackInfo? {
        guard let server, let streamURL = plexTrack.streamURL(server: server) else { return nil }

        let plexId = Int64(plexTrack.ratingKey) ?? 0

        let track = Track(
            id: -plexId, // negative to avoid collision with local IDs
            filePath: streamURL.absoluteString,
            title: plexTrack.title,
            albumId: album.flatMap { Int64($0.ratingKey) }.map { -$0 },
            artistId: plexTrack.grandparentRatingKey.flatMap { Int64($0) }.map { -$0 },
            genre: nil,
            trackNumber: plexTrack.index,
            discNumber: plexTrack.parentIndex,
            duration: plexTrack.durationSeconds,
            fileSize: nil,
            dateAdded: Date(),
            playCount: 0,
            lastPlayedAt: nil,
            isFavorite: false
        )

        let albumModel: Album? = {
            guard let album else { return nil }
            let artworkURL = album.artworkURL(server: server)
            return Album(
                id: Int64(album.ratingKey).map { -$0 },
                title: album.title,
                artistId: album.parentRatingKey.flatMap { Int64($0) }.map { -$0 },
                year: album.year,
                artworkPath: artworkURL?.absoluteString
            )
        }()

        let artistModel: Artist? = {
            guard let name = plexTrack.grandparentTitle else { return nil }
            let artistId = plexTrack.grandparentRatingKey.flatMap { Int64($0) }.map { -$0 }
            return Artist(id: artistId, name: name)
        }()

        return TrackInfo(track: track, album: albumModel, artist: artistModel)
    }

    // Convert an array of PlexTracks to TrackInfos
    func makeTrackInfos(from plexTracks: [PlexTrack], album: PlexAlbum? = nil) -> [TrackInfo] {
        plexTracks.compactMap { makeTrackInfo(from: $0, album: album) }
    }
}
