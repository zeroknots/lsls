import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(SyncManager.self) private var syncManager

    var body: some View {
        @Bindable var syncManager = syncManager

        Form {
            Section("Rockbox Device") {
                HStack {
                    TextField("Mount Path", text: $syncManager.settings.mountPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        browseMountPath()
                    }
                }

                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(syncManager.isDeviceConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(syncManager.isDeviceConnected ? "Connected" : "Not Connected")
                    }
                }
            }

            Section("Sync") {
                Toggle("Auto-sync when device is connected", isOn: $syncManager.settings.autoSyncEnabled)

                LabeledContent("Items in sync list") {
                    Text("\(syncManager.syncItems.count)")
                }

                if let lastSync = syncManager.lastSyncDate {
                    LabeledContent("Last sync") {
                        Text(lastSync, style: .relative)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
        .padding()
        .onChange(of: syncManager.settings) {
            syncManager.saveSettings()
        }
    }

    private func browseMountPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select Rockbox mount point"
        if panel.runModal() == .OK, let url = panel.url {
            syncManager.settings.mountPath = url.path
        }
    }
}
