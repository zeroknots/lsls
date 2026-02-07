import AppKit
import SwiftUI

@main
struct FLACMusicApp: App {
    @State private var databaseManager = DatabaseManager.shared
    @State private var playerState = PlayerState()
    @State private var libraryManager = LibraryManager()
    @State private var themeManager = ThemeManager()
    @State private var syncManager = SyncManager()
    @State private var plexState = PlexConnectionState()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerState)
                .environment(libraryManager)
                .environment(plexState)
                .environment(themeManager)
                .environment(\.theme, themeManager.current)
                .environment(\.themeColors, themeManager.resolvedColors)
                .environment(syncManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .accentColor(themeManager.resolvedColors.accent)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Playback") {
                Button("Play / Pause") {
                    playerState.togglePlayPause()
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Next Track") {
                    playerState.playNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("Previous Track") {
                    playerState.playPrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("Increase Volume") {
                    playerState.volume = min(1.0, playerState.volume + 0.1)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("Decrease Volume") {
                    playerState.volume = max(0.0, playerState.volume - 0.1)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Divider()

                Button("Toggle Shuffle") {
                    playerState.toggleShuffle()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Cycle Repeat") {
                    playerState.cycleRepeat()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Theme") {
                ForEach(BuiltInThemes.all, id: \.meta.name) { theme in
                    Button(theme.meta.name) {
                        themeManager.applyBuiltIn(theme)
                    }
                }

                Divider()

                Button("Open Theme File") {
                    themeManager.openThemeFile()
                }

                Button("Reload Theme") {
                    themeManager.reload()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(syncManager)
        }
    }
}
