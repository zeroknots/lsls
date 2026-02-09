import Foundation
import GRDB

struct Episode: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var podcastId: Int64
    var title: String
    var audioUrl: String
    var localFilePath: String?
    var pubDate: Date
    var duration: TimeInterval
    var fileSize: Int64?
    var episodeDescription: String?
    var isDownloaded: Bool
    var isPlayed: Bool
    var playbackPosition: TimeInterval
    var dateAdded: Date

    enum CodingKeys: String, CodingKey {
        case id, podcastId, title, audioUrl, localFilePath, pubDate, duration, fileSize
        case episodeDescription = "description"
        case isDownloaded, isPlayed, playbackPosition, dateAdded
    }
}

extension Episode: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "episode"

    static let podcast = belongsTo(Podcast.self)

    var podcast: QueryInterfaceRequest<Podcast> {
        request(for: Episode.podcast)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
