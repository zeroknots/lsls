import Foundation

struct RockboxTheme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let path: URL
    let dateAdded: Date
    var isInstalledOnDevice: Bool = false
}

@MainActor
@Observable
final class RockboxThemeManager {
    var installedThemes: [RockboxTheme] = []
    var isInstalling = false
    var installStatus: String = ""

    private let themesDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        themesDirectory = appSupport.appendingPathComponent("LSLS/RockboxThemes", isDirectory: true)
        try? FileManager.default.createDirectory(at: themesDirectory, withIntermediateDirectories: true)
        loadThemes()
    }

    func loadThemes() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: themesDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            installedThemes = []
            return
        }

        installedThemes = entries.compactMap { url -> RockboxTheme? in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            let name = url.lastPathComponent
            return RockboxTheme(id: name, name: name, path: url, dateAdded: creationDate)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func importTheme(from zipURL: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extract zip to temp directory
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", tempDir.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ThemeError.extractionFailed
        }

        // Find the .rockbox directory inside the extracted content
        let rockboxDir = tempDir.appendingPathComponent(".rockbox")
        guard FileManager.default.fileExists(atPath: rockboxDir.path) else {
            throw ThemeError.noRockboxDirectory
        }

        // Determine theme name from the .cfg file in themes/ subfolder
        let themeName = try resolveThemeName(in: rockboxDir, fallback: zipURL.deletingPathExtension().lastPathComponent)

        // Copy to our themes storage
        let destDir = themesDirectory.appendingPathComponent(themeName)
        let fm = FileManager.default

        if fm.fileExists(atPath: destDir.path) {
            try fm.removeItem(at: destDir)
        }

        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Copy the .rockbox contents preserving structure
        try copyContents(of: rockboxDir, to: destDir)

        loadThemes()
    }

    func deleteTheme(_ theme: RockboxTheme) throws {
        try FileManager.default.removeItem(at: theme.path)
        loadThemes()
    }

    func installThemesToDevice(themes: [RockboxTheme], deviceMountPath: String) async throws {
        isInstalling = true
        defer { isInstalling = false }

        let deviceRockbox = URL(fileURLWithPath: deviceMountPath).appendingPathComponent(".rockbox")

        for (index, theme) in themes.enumerated() {
            installStatus = "Installing \(theme.name) (\(index + 1)/\(themes.count))..."

            try await Task.detached(priority: .utility) {
                try self.mergeThemeToDevice(theme: theme, deviceRockbox: deviceRockbox)
            }.value
        }

        installStatus = "Installed \(themes.count) theme\(themes.count == 1 ? "" : "s")"
    }

    // MARK: - Private

    private nonisolated func mergeThemeToDevice(theme: RockboxTheme, deviceRockbox: URL) throws {
        let fm = FileManager.default
        let themePath = theme.path

        // Walk the theme directory and copy each file into the device's .rockbox/
        guard let enumerator = fm.enumerator(
            at: themePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            let relativePath = fileURL.path.replacingOccurrences(of: themePath.path + "/", with: "")
            let destURL = deviceRockbox.appendingPathComponent(relativePath)

            if resourceValues.isDirectory == true {
                try fm.createDirectory(at: destURL, withIntermediateDirectories: true)
            } else {
                let destDir = destURL.deletingLastPathComponent()
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: fileURL, to: destURL)
            }
        }
    }

    private func resolveThemeName(in rockboxDir: URL, fallback: String) throws -> String {
        let themesDir = rockboxDir.appendingPathComponent("themes")
        if let cfgFiles = try? FileManager.default.contentsOfDirectory(atPath: themesDir.path) {
            if let cfgFile = cfgFiles.first(where: { $0.hasSuffix(".cfg") }) {
                return (cfgFile as NSString).deletingPathExtension
            }
        }
        return fallback
    }

    private func copyContents(of source: URL, to dest: URL) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in contents {
            let destItem = dest.appendingPathComponent(item.lastPathComponent)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                try fm.createDirectory(at: destItem, withIntermediateDirectories: true)
                try copyContents(of: item, to: destItem)
            } else {
                try fm.copyItem(at: item, to: destItem)
            }
        }
    }
}

enum ThemeError: LocalizedError {
    case extractionFailed
    case noRockboxDirectory

    var errorDescription: String? {
        switch self {
        case .extractionFailed:
            return "Failed to extract theme zip file"
        case .noRockboxDirectory:
            return "Theme zip does not contain a .rockbox directory"
        }
    }
}
