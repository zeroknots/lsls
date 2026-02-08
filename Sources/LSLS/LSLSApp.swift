import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
        return true
    }
}

private struct ThemedContentView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ContentView()
            .environment(\.theme, themeManager.current)
            .environment(\.themeColors, themeManager.resolvedColors)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .accentColor(themeManager.resolvedColors.accent)
    }
}

@main
struct LSLSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var databaseManager = DatabaseManager.shared
    @State private var playerState = PlayerState()
    @State private var libraryManager = LibraryManager()
    @State private var themeManager = ThemeManager()
    @State private var syncManager = SyncManager()
    @State private var plexState = PlexConnectionState()
    @State private var updateChecker = UpdateChecker()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ThemedContentView()
                .environment(playerState)
                .environment(libraryManager)
                .environment(plexState)
                .environment(themeManager)
                .environment(syncManager)
                .frame(minWidth: 900, minHeight: 600)
                .task { updateChecker.checkForUpdates() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateChecker.checkForUpdates(silent: false)
                }
            }

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

        MenuBarExtra("LS", isInserted: .constant(true)) {
            MenuBarPlayerView()
                .environment(playerState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(syncManager)
        }
    }
}
