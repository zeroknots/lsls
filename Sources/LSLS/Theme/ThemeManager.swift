import Foundation
import SwiftUI

@MainActor
@Observable
final class ThemeManager {
    var current: ThemeDefinition {
        didSet { resolvedColors = ResolvedThemeColors(from: current.colors) }
    }
    var resolvedColors: ResolvedThemeColors

    private nonisolated(unsafe) var fileWatcher: (any DispatchSourceFileSystemObject)?
    private let configDir: URL
    private let configFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configDir = home.appendingPathComponent(".config/lsls", isDirectory: true)
        self.configFile = configDir.appendingPathComponent("theme.json")

        let loaded = ThemeManager.loadTheme(from: configFile)
        self.current = loaded
        self.resolvedColors = ResolvedThemeColors(from: loaded.colors)

        startWatching()
    }

    deinit {
        fileWatcher?.cancel()
    }

    func applyBuiltIn(_ theme: ThemeDefinition) {
        current = theme
        writeThemeFile(theme)
    }

    func reload() {
        let loaded = ThemeManager.loadTheme(from: configFile)
        guard loaded != current else { return }
        current = loaded
    }

    func openThemeFile() {
        ensureConfigDir()
        if !FileManager.default.fileExists(atPath: configFile.path) {
            writeThemeFile(current)
        }
        NSWorkspace.shared.open(configFile)
    }

    var preferredColorScheme: ColorScheme? {
        switch current.meta.colorSchemeHint?.lowercased() {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    // MARK: - Private

    private static func loadTheme(from url: URL) -> ThemeDefinition {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return BuiltInThemes.darkMinimal
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ThemeDefinition.self, from: data)
        } catch {
            print("[ThemeManager] Failed to parse theme.json: \(error). Using default.")
            return BuiltInThemes.darkMinimal
        }
    }

    private func ensureConfigDir() {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    private func writeThemeFile(_ theme: ThemeDefinition) {
        ensureConfigDir()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(theme) {
            try? data.write(to: configFile, options: .atomic)
        }
    }

    private func startWatching() {
        let dir = configDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.reload()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.fileWatcher = source
    }
}
