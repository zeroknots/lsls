import Foundation

// MARK: - PlexAPIError

enum PlexAPIError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, data: Data)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .httpError(let code, _):
            "HTTP error \(code)"
        case .noData:
            "No data received"
        }
    }
}

// MARK: - PlexAPIClient

actor PlexAPIClient {

    // MARK: - Static Properties

    static let productName = "FLACMusic"
    static let productVersion = "1.0"

    // MARK: - Properties

    private let session: URLSession
    private let clientIdentifier: String

    // MARK: - Initialization

    init() {
        self.session = URLSession(configuration: .default)

        let key = "PlexClientIdentifier"
        if let existing = UserDefaults.standard.string(forKey: key) {
            self.clientIdentifier = existing
        } else {
            let generated = UUID().uuidString
            UserDefaults.standard.set(generated, forKey: key)
            self.clientIdentifier = generated
        }
    }

    // MARK: - Core Request

    func request<T: Decodable & Sendable>(
        url: URL,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil
    ) async throws -> T {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body

        // Standard Plex headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        urlRequest.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        urlRequest.setValue(Self.productName, forHTTPHeaderField: "X-Plex-Product")
        urlRequest.setValue(Self.productVersion, forHTTPHeaderField: "X-Plex-Version")
        urlRequest.setValue("macOS", forHTTPHeaderField: "X-Plex-Platform")
        urlRequest.setValue(ProcessInfo.processInfo.hostName, forHTTPHeaderField: "X-Plex-Device-Name")

        if let token {
            urlRequest.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexAPIError.noData
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PlexAPIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Convenience Methods

    func getLibrarySections(server: PlexServer) async throws -> [PlexLibrarySection] {
        let urlString = "\(baseURL(for: server))/library/sections"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<PlexLibrarySection> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    func getArtists(server: PlexServer, sectionKey: String) async throws -> [PlexArtist] {
        let urlString = "\(baseURL(for: server))/library/sections/\(sectionKey)/all?type=8"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<PlexArtist> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    func getAlbums(server: PlexServer, sectionKey: String) async throws -> [PlexAlbum] {
        let urlString = "\(baseURL(for: server))/library/sections/\(sectionKey)/all?type=9"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<PlexAlbum> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    func getAlbumsForArtist(server: PlexServer, artistRatingKey: String) async throws -> [PlexAlbum] {
        let urlString = "\(baseURL(for: server))/library/metadata/\(artistRatingKey)/children"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<PlexAlbum> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    func getTracksForAlbum(server: PlexServer, albumRatingKey: String) async throws -> [PlexTrack] {
        let urlString = "\(baseURL(for: server))/library/metadata/\(albumRatingKey)/children"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<PlexTrack> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    func search<T: Decodable & Sendable>(
        server: PlexServer,
        sectionKey: String,
        query: String,
        type: Int
    ) async throws -> [T] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw PlexAPIError.invalidURL
        }
        let urlString = "\(baseURL(for: server))/library/sections/\(sectionKey)/search?type=\(type)&query=\(encodedQuery)"
        guard let url = URL(string: urlString) else {
            throw PlexAPIError.invalidURL
        }
        let response: PlexResponse<T> = try await request(
            url: url,
            token: server.token
        )
        return response.mediaContainer.items
    }

    // MARK: - Helpers

    private func baseURL(for server: PlexServer) -> String {
        "\(server.scheme)://\(server.host):\(server.port)"
    }
}
