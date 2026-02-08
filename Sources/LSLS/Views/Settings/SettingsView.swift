import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
        .frame(width: 480, height: 500)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(LibraryManager.self) private var libraryManager

    var body: some View {
        Form {
            Section("Music Library") {
                HStack {
                    Button("Import Folder...") {
                        importFolder()
                    }
                    .disabled(libraryManager.isImporting)

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
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder to import music from"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await libraryManager.importFolder(url)
            }
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
    @Environment(RockboxThemeManager.self) private var themeManager

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
                Toggle("Install themes to device", isOn: $syncManager.settings.syncThemesEnabled)

                LabeledContent("Items in sync list") {
                    Text("\(syncManager.syncItems.count)")
                }

                if let lastSync = syncManager.lastSyncDate {
                    LabeledContent("Last sync") {
                        Text(lastSync, style: .relative)
                    }
                }
            }

            Section("Rockbox Themes") {
                if themeManager.installedThemes.isEmpty {
                    Text("No themes imported")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(themeManager.installedThemes) { theme in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.name)
                                Text(theme.dateAdded, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Install") {
                                installTheme(theme)
                            }
                            .disabled(!syncManager.isDeviceConnected || themeManager.isInstalling)
                            Button(role: .destructive) {
                                try? themeManager.deleteTheme(theme)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    Button("Import Theme (.zip)...") {
                        importTheme()
                    }

                    if themeManager.installedThemes.count > 1 {
                        Button("Install All") {
                            installAllThemes()
                        }
                        .disabled(!syncManager.isDeviceConnected || themeManager.isInstalling)
                    }
                }

                if themeManager.isInstalling {
                    Text(themeManager.installStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = true
        panel.message = "Select Rockbox theme zip files"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                try themeManager.importTheme(from: url)
            } catch {
                print("Failed to import theme: \(error)")
            }
        }
    }

    private func installTheme(_ theme: RockboxTheme) {
        Task {
            do {
                try await themeManager.installThemesToDevice(
                    themes: [theme],
                    deviceMountPath: syncManager.settings.mountPath
                )
            } catch {
                print("Failed to install theme: \(error)")
            }
        }
    }

    private func installAllThemes() {
        Task {
            do {
                try await themeManager.installThemesToDevice(
                    themes: themeManager.installedThemes,
                    deviceMountPath: syncManager.settings.mountPath
                )
            } catch {
                print("Failed to install themes: \(error)")
            }
        }
    }
}
