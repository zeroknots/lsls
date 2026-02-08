import SwiftUI

struct SyncListView: View {
    @Environment(SyncManager.self) private var syncManager

    private var artists: [SyncItem] { syncManager.syncItems.filter { $0.itemType == .artist } }
    private var albums: [SyncItem] { syncManager.syncItems.filter { $0.itemType == .album } }
    private var tracks: [SyncItem] { syncManager.syncItems.filter { $0.itemType == .track } }

    private var subtitleText: String {
        var parts: [String] = []
        if !artists.isEmpty { parts.append("\(artists.count) artist\(artists.count == 1 ? "" : "s")") }
        if !albums.isEmpty { parts.append("\(albums.count) album\(albums.count == 1 ? "" : "s")") }
        if !tracks.isEmpty { parts.append("\(tracks.count) song\(tracks.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "No items" : parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync List")
                        .font(.title.bold())
                    Text(subtitleText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Device status
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncManager.isDeviceConnected ? .green : .red)
                        .frame(width: 10, height: 10)
                    Text(syncManager.isDeviceConnected ? "Device Connected" : "Device Not Found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if syncManager.isSyncing {
                    Button("Cancel") {
                        syncManager.cancelSync()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Sync Now") {
                        syncManager.startSync()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!syncManager.isDeviceConnected || syncManager.syncItems.isEmpty)
                }
            }
            .padding(24)

            // Sync progress
            if syncManager.isSyncing {
                VStack(spacing: 4) {
                    ProgressView(value: syncManager.syncProgress)
                    Text(syncManager.syncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            // Error banner
            if let error = syncManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.subheadline)
                    Spacer()
                    Button("Dismiss") { syncManager.syncError = nil }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(.yellow.opacity(0.1))
            }

            // Last sync info
            if !syncManager.isSyncing, !syncManager.syncStatus.isEmpty {
                HStack {
                    Text(syncManager.syncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            Divider()

            // Sync items list
            if syncManager.syncItems.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text("Right-click on songs, albums, or artists to add them to your sync list")
                }
                .padding(.top, 60)
                Spacer()
            } else {
                List {
                    syncSection("Artists", icon: "music.mic", items: artists)
                    syncSection("Albums", icon: "square.stack", items: albums)
                    syncSection("Songs", icon: "music.note", items: tracks)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Sync List")
    }

    @ViewBuilder
    private func syncSection(_ title: String, icon: String, items: [SyncItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    SyncItemRow(item: item)
                        .contextMenu {
                            Button("Remove from Sync List", role: .destructive) {
                                syncManager.removeSyncItem(item)
                            }
                        }
                }
                .onDelete { offsets in
                    for index in offsets {
                        syncManager.removeSyncItem(items[index])
                    }
                }
            } header: {
                Label(title, systemImage: icon)
            }
        }
    }
}
