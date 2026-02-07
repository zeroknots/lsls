import SwiftUI

struct SyncListView: View {
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync List")
                        .font(.title.bold())
                    Text("\(syncManager.syncItems.count) items")
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
                    ForEach(syncManager.syncItems) { item in
                        SyncItemRow(item: item)
                            .contextMenu {
                                Button("Remove from Sync List", role: .destructive) {
                                    syncManager.removeSyncItem(item)
                                }
                            }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            syncManager.removeSyncItem(syncManager.syncItems[index])
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Sync List")
    }
}
