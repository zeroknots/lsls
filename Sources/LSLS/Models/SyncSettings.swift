import Foundation
import GRDB

struct SyncSettingRow: Codable, Equatable, Sendable {
    var key: String
    var value: String
}

extension SyncSettingRow: FetchableRecord, PersistableRecord {
    static let databaseTableName = "syncSettings"
}

struct RockboxSettings: Equatable, Sendable {
    var mountPath: String = "/Volumes/ROCKBOX"
    var autoSyncEnabled: Bool = false
    var pollingIntervalSeconds: Int = 10
    var syncPlayCountsEnabled: Bool = true
    var syncPlaylistsEnabled: Bool = true
    var syncPodcastsEnabled: Bool = true
    var syncThemesEnabled: Bool = false

    static func load(from db: Database) throws -> RockboxSettings {
        let rows = try SyncSettingRow.fetchAll(db)
        var settings = RockboxSettings()
        for row in rows {
            switch row.key {
            case "rockboxMountPath": settings.mountPath = row.value
            case "autoSyncEnabled": settings.autoSyncEnabled = row.value == "true"
            case "pollingIntervalSeconds": settings.pollingIntervalSeconds = Int(row.value) ?? 10
            case "syncPlayCountsEnabled": settings.syncPlayCountsEnabled = row.value == "true"
            case "syncPlaylistsEnabled": settings.syncPlaylistsEnabled = row.value == "true"
            case "syncPodcastsEnabled": settings.syncPodcastsEnabled = row.value == "true"
            case "syncThemesEnabled": settings.syncThemesEnabled = row.value == "true"
            default: break
            }
        }
        return settings
    }

    func save(to db: Database) throws {
        try SyncSettingRow(key: "rockboxMountPath", value: mountPath).save(db)
        try SyncSettingRow(key: "autoSyncEnabled", value: autoSyncEnabled ? "true" : "false").save(db)
        try SyncSettingRow(key: "pollingIntervalSeconds", value: "\(pollingIntervalSeconds)").save(db)
        try SyncSettingRow(key: "syncPlayCountsEnabled", value: syncPlayCountsEnabled ? "true" : "false").save(db)
        try SyncSettingRow(key: "syncPlaylistsEnabled", value: syncPlaylistsEnabled ? "true" : "false").save(db)
        try SyncSettingRow(key: "syncPodcastsEnabled", value: syncPodcastsEnabled ? "true" : "false").save(db)
        try SyncSettingRow(key: "syncThemesEnabled", value: syncThemesEnabled ? "true" : "false").save(db)
    }
}
