import Foundation
import GRDB

struct Podcast: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var title: String
    var author: String?
    var feedUrl: String
    var artworkUrl: String?
    var podcastDescription: String?
    var lastFetchedAt: Date?
    var dateSubscribed: Date

    enum CodingKeys: String, CodingKey {
        case id, title, author, feedUrl, artworkUrl
        case podcastDescription = "description"
        case lastFetchedAt, dateSubscribed
    }
}

extension Podcast: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "podcast"

    static let episodes = hasMany(Episode.self)

    var episodes: QueryInterfaceRequest<Episode> {
        request(for: Podcast.episodes)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
