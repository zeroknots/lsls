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

    static func load(from db: Database) throws -> RockboxSettings {
        let rows = try SyncSettingRow.fetchAll(db)
        var settings = RockboxSettings()
        for row in rows {
            switch row.key {
            case "rockboxMountPath": settings.mountPath = row.value
            case "autoSyncEnabled": settings.autoSyncEnabled = row.value == "true"
            case "pollingIntervalSeconds": settings.pollingIntervalSeconds = Int(row.value) ?? 10
            default: break
            }
        }
        return settings
    }

    func save(to db: Database) throws {
        try SyncSettingRow(key: "rockboxMountPath", value: mountPath).save(db)
        try SyncSettingRow(key: "autoSyncEnabled", value: autoSyncEnabled ? "true" : "false").save(db)
        try SyncSettingRow(key: "pollingIntervalSeconds", value: "\(pollingIntervalSeconds)").save(db)
    }
}
