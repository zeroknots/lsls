import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }

            ThemeSettingsTab()
                .tabItem { Label("Theme", systemImage: "paintbrush") }

            DAPSyncSettingsTab()
                .tabItem { Label("DAP Sync", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480, height: 340)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(LibraryManager.self) private var libraryManager

    var body: some View {
        @Bindable var libraryManager = libraryManager

        Form {
            Section("Music Library") {
                HStack {
                    TextField("Library Folder", text: $libraryManager.libraryFolderPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        browseLibraryFolder()
                    }
                }

                HStack {
                    Button("Re-scan Library") {
                        rescanLibrary()
                    }
                    .disabled(libraryManager.libraryFolderPath.isEmpty || libraryManager.isImporting)

                    if libraryManager.isImporting {
                        ProgressView()
                            .controlSize(.small)
                        Text(libraryManager.importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { libraryManager.loadLibraryFolder() }
        .onChange(of: libraryManager.libraryFolderPath) {
            libraryManager.saveLibraryFolder()
        }
    }

    private func browseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select your music library folder"
        if panel.runModal() == .OK, let url = panel.url {
            libraryManager.libraryFolderPath = url.path
        }
    }

    private func rescanLibrary() {
        let path = libraryManager.libraryFolderPath
        guard !path.isEmpty else { return }
        Task {
            await libraryManager.importFolder(URL(fileURLWithPath: path))
        }
    }
}

// MARK: - Theme

private struct ThemeSettingsTab: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Form {
            Section("Built-in Themes") {
                themeList
            }

            Section("Custom Theme") {
                customThemeButtons
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var themeList: some View {
        ForEach(BuiltInThemes.all, id: \.meta.name) { theme in
            ThemeRow(theme: theme, isActive: themeManager.current.meta.name == theme.meta.name) {
                themeManager.applyBuiltIn(theme)
            }
        }
    }

    @ViewBuilder
    private var customThemeButtons: some View {
        HStack {
            Button("Open Theme File") {
                themeManager.openThemeFile()
            }

            Button("Reload Theme") {
                themeManager.reload()
            }
        }
    }
}

private struct ThemeRow: View {
    let theme: ThemeDefinition
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(theme.meta.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DAP Sync

private struct DAPSyncSettingsTab: View {
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
                Toggle("Sync play counts & ratings", isOn: $syncManager.settings.syncPlayCountsEnabled)
                Toggle("Export playlists to device", isOn: $syncManager.settings.syncPlaylistsEnabled)

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
