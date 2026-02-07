import Foundation
import GRDB

struct SmartPlaylist: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var dateCreated: Date

    init(id: Int64? = nil, name: String, dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.dateCreated = dateCreated
    }
}

extension SmartPlaylist: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "smartPlaylist"

    static let rules = hasMany(SmartPlaylistRule.self)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

enum SmartPlaylistField: String, Codable, CaseIterable, Hashable {
    case playCount
    case isFavorite
    case artist
    case genre
    case dateAdded
    case lastPlayedAt

    var displayName: String {
        switch self {
        case .playCount: "Play Count"
        case .isFavorite: "Is Favorite"
        case .artist: "Artist"
        case .genre: "Genre"
        case .dateAdded: "Date Added"
        case .lastPlayedAt: "Last Played"
        }
    }

    var availableOperators: [SmartPlaylistOperator] {
        switch self {
        case .playCount:
            return [.greaterThan, .lessThan, .equals]
        case .isFavorite:
            return [.isTrue]
        case .artist, .genre:
            return [.equals, .contains]
        case .dateAdded, .lastPlayedAt:
            return [.greaterThan, .lessThan]
        }
    }
}

enum SmartPlaylistOperator: String, Codable, CaseIterable, Hashable {
    case greaterThan
    case lessThan
    case equals
    case contains
    case isTrue

    var displayName: String {
        switch self {
        case .greaterThan: "greater than"
        case .lessThan: "less than"
        case .equals: "is"
        case .contains: "contains"
        case .isTrue: "is true"
        }
    }
}

struct SmartPlaylistRule: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var smartPlaylistId: Int64
    var field: SmartPlaylistField
    var `operator`: SmartPlaylistOperator
    var value: String
    var position: Int
}

extension SmartPlaylistRule: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "smartPlaylistRule"

    static let smartPlaylist = belongsTo(SmartPlaylist.self)

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
