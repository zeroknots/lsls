import SwiftUI
import GRDB

struct SyncItemRow: View {
    let item: SyncItem
    @State private var displayName: String = ""
    @State private var subtitle: String = ""
    @State private var iconName: String = "music.note"

    private let db = DatabaseManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.itemType.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .task { resolveDisplayInfo() }
    }

    private func resolveDisplayInfo() {
        do {
            try db.dbQueue.read { db in
                switch item.itemType {
                case .track:
                    if let trackId = item.trackId,
                       let track = try Track.fetchOne(db, key: trackId) {
                        displayName = track.title
                        if let artistId = track.artistId,
                           let artist = try Artist.fetchOne(db, key: artistId) {
                            subtitle = artist.name
                        }
                        iconName = "music.note"
                    }
                case .album:
                    if let albumId = item.albumId,
                       let album = try Album.fetchOne(db, key: albumId) {
                        displayName = album.title
                        if let artistId = album.artistId,
                           let artist = try Artist.fetchOne(db, key: artistId) {
                            subtitle = artist.name
                        }
                        iconName = "square.stack"
                    }
                case .artist:
                    if let artistId = item.artistId,
                       let artist = try Artist.fetchOne(db, key: artistId) {
                        displayName = artist.name
                        let albumCount = try Album
                            .filter(Album.Columns.artistId == artistId)
                            .fetchCount(db)
                        subtitle = "\(albumCount) album\(albumCount == 1 ? "" : "s")"
                        iconName = "music.mic"
                    }
                }
            }
        } catch {
            displayName = "Unknown"
        }
    }
}
