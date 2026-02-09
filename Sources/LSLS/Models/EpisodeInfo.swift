import Foundation
import GRDB

struct EpisodeInfo: Codable, FetchableRecord, Equatable, Hashable, Identifiable {
    var episode: Episode
    var podcast: Podcast?
    var id: Int64? { episode.id }
}
