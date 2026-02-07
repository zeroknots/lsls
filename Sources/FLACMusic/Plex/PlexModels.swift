import Foundation

// MARK: - Generic Response Wrapper

struct PlexResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let mediaContainer: MediaContainer

    struct MediaContainer: Decodable, Sendable {
        let size: Int?
        let metadata: [T]?
        let directory: [T]?

        enum CodingKeys: String, CodingKey {
            case size
            case metadata = "Metadata"
            case directory = "Directory"
        }

        var items: [T] {
            metadata ?? directory ?? []
        }
    }

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

// MARK: - Library Section

struct PlexLibrarySection: Codable, Sendable, Identifiable, Hashable {
    let key: String
    let title: String
    let type: String

    var id: String { key }
}

// MARK: - Artist

struct PlexArtist: Codable, Sendable, Identifiable, Hashable {
    let ratingKey: String
    let title: String
    let thumb: String?

    var id: String { ratingKey }
}

// MARK: - Album

struct PlexAlbum: Codable, Sendable, Identifiable, Hashable {
    let ratingKey: String
    let title: String
    let parentRatingKey: String?
    let parentTitle: String?
    let year: Int?
    let thumb: String?

    var id: String { ratingKey }
}

// MARK: - Track

struct PlexTrack: Codable, Sendable, Identifiable, Hashable {
    let ratingKey: String
    let title: String
    let parentRatingKey: String?
    let parentTitle: String?
    let grandparentRatingKey: String?
    let grandparentTitle: String?
    let index: Int?
    let parentIndex: Int?
    let duration: Int?
    let Media: [PlexMedia]?

    var id: String { ratingKey }
}

// MARK: - Media

struct PlexMedia: Codable, Sendable, Hashable {
    let Part: [PlexPart]?
}

// MARK: - Part

struct PlexPart: Codable, Sendable, Hashable {
    let key: String
    let file: String?
    let container: String?
}

// MARK: - Server

struct PlexServer: Codable, Sendable, Identifiable, Hashable, Equatable {
    let name: String
    let host: String
    let port: Int
    let scheme: String
    let token: String

    var id: String { "\(host):\(port)" }
}

// MARK: - Pin (Auth Flow)

struct PlexPin: Codable, Sendable {
    let id: Int
    let code: String
    let authToken: String?
}

// MARK: - Resource (Server Discovery)

struct PlexResource: Codable, Sendable {
    let name: String
    let provides: String
    let connections: [PlexConnection]
}

// MARK: - Connection

struct PlexConnection: Codable, Sendable {
    let uri: String
    let local: Bool
    let connectionProtocol: String

    enum CodingKeys: String, CodingKey {
        case uri
        case local
        case connectionProtocol = "protocol"
    }
}

// MARK: - PlexTrack Helpers

extension PlexTrack {
    func streamURL(server: PlexServer) -> URL? {
        guard let part = Media?.first?.Part?.first else { return nil }
        return URL(string: "\(server.scheme)://\(server.host):\(server.port)\(part.key)?X-Plex-Token=\(server.token)")
    }

    var durationSeconds: TimeInterval {
        guard let ms = duration else { return 0 }
        return TimeInterval(ms) / 1000.0
    }
}

// MARK: - PlexAlbum Helpers

extension PlexAlbum {
    func artworkURL(server: PlexServer) -> URL? {
        guard let thumb else { return nil }
        return URL(string: "\(server.scheme)://\(server.host):\(server.port)\(thumb)?X-Plex-Token=\(server.token)")
    }
}

// MARK: - PlexArtist Helpers

extension PlexArtist {
    func artworkURL(server: PlexServer) -> URL? {
        guard let thumb else { return nil }
        return URL(string: "\(server.scheme)://\(server.host):\(server.port)\(thumb)?X-Plex-Token=\(server.token)")
    }
}
