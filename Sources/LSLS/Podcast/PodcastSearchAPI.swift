import Foundation

struct ApplePodcastSearchResult: Codable, Identifiable {
    let collectionId: Int
    let collectionName: String
    let artistName: String?
    let feedUrl: String
    let artworkUrl100: String?
    let artworkUrl600: String?
    let trackCount: Int?

    var id: Int { collectionId }
}

struct ApplePodcastSearchResponse: Codable {
    let resultCount: Int
    let results: [ApplePodcastSearchResult]
}

enum PodcastSearchAPI {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    static func search(query: String, limit: Int = 25) async throws -> [ApplePodcastSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw PodcastError.invalidQuery
        }

        let urlString = "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&limit=\(limit)"
        guard let url = URL(string: urlString) else {
            throw PodcastError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PodcastError.httpError(statusCode: code)
        }

        let searchResponse = try JSONDecoder().decode(ApplePodcastSearchResponse.self, from: data)
        return searchResponse.results
    }
}
