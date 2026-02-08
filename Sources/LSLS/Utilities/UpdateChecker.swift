import AppKit
import Foundation

@MainActor
@Observable
final class UpdateChecker {
    private static let repo = "zeroknots/lsls"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    var updateAvailable: Release?
    private(set) var isUpdating = false
    private(set) var downloadProgress: Double = 0
    private(set) var statusText = ""

    private var progressObservation: NSKeyValueObservation?
    private var progressPanel: NSPanel?
    private var progressBar: NSProgressIndicator?
    private var statusLabel: NSTextField?

    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    struct Release: Decodable, Sendable {
        let tagName: String
        let htmlUrl: String
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case body
            case assets
        }

        var version: String {
            tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        }

        var dmgURL: URL? {
            guard let dmg = assets.first(where: { $0.name.hasSuffix(".dmg") }) else { return nil }
            return URL(string: dmg.browserDownloadUrl)
        }
    }

    // MARK: - Check

    func checkForUpdates(silent: Bool = true) {
        Task {
            let release: Release
            do {
                release = try await fetchLatestRelease()
            } catch {
                if !silent { showCheckFailedAlert() }
                return
            }

            guard isNewer(release.version, than: currentVersion) else {
                if !silent { showUpToDateAlert() }
                return
            }

            updateAvailable = release
            showUpdateAlert(release)
        }
    }

    // MARK: - Alerts

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "LSLS \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showCheckFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not reach GitHub to check for updates. Please try again later."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showUpdateAlert(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "LSLS \(release.version) Available"
        alert.informativeText = release.body ?? "A new version is available."
        alert.alertStyle = .informational

        if release.dmgURL != nil {
            alert.addButton(withTitle: "Update Now")
        } else {
            alert.addButton(withTitle: "View Release")
        }
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if release.dmgURL != nil {
                Task { await performUpdate(release) }
            } else if let url = URL(string: release.htmlUrl) {
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
            }
        }
    }

    // MARK: - Auto Update

    private func performUpdate(_ release: Release) async {
        guard let dmgURL = release.dmgURL else { return }

        isUpdating = true
        downloadProgress = 0
        statusText = "Downloading LSLS \(release.version)..."

        let panel = makeProgressPanel()
        panel.makeKeyAndOrderFront(nil)

        do {
            let dmgPath = try await downloadDMG(from: dmgURL)

            statusText = "Installing..."
            progressBar?.isIndeterminate = true
            progressBar?.startAnimation(nil)

            let appURL = Bundle.main.bundleURL
            try await Self.install(dmg: dmgPath, replacingAppAt: appURL)

            panel.close()
            Self.relaunch(appAt: appURL)
        } catch {
            panel.close()
            cleanup()

            let alert = NSAlert()
            alert.messageText = "Update Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func downloadDMG(from url: URL) async throws -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).dmg")

        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.downloadProgress = progress.fractionCompleted
                    self.progressBar?.doubleValue = progress.fractionCompleted
                }
            }
            task.resume()
        }
    }

    // Runs off the main actor to avoid blocking UI with Process calls
    private nonisolated static func install(dmg: URL, replacingAppAt appURL: URL) async throws {
        let mountPoint = try mountDMG(at: dmg)
        defer { detachDMG(mountPoint: mountPoint) }

        let contents = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw UpdateError.appNotFound
        }

        let sourceApp = URL(fileURLWithPath: mountPoint).appendingPathComponent(appName)

        // Copy to temp first so we can unmount the DMG before replacing
        let tempApp = FileManager.default.temporaryDirectory.appendingPathComponent(appName)
        if FileManager.default.fileExists(atPath: tempApp.path) {
            try FileManager.default.removeItem(at: tempApp)
        }
        try FileManager.default.copyItem(at: sourceApp, to: tempApp)

        // Atomic replace
        _ = try FileManager.default.replaceItemAt(appURL, withItemAt: tempApp)

        // Clean up DMG
        try? FileManager.default.removeItem(at: dmg)
    }

    private nonisolated static func mountDMG(at path: URL) throws -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["attach", path.path, "-nobrowse", "-noverify", "-plist"]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard proc.terminationStatus == 0,
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            throw UpdateError.mountFailed
        }
        return mountPoint
    }

    private nonisolated static func detachDMG(mountPoint: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["detach", mountPoint, "-quiet"]
        try? proc.run()
        proc.waitUntilExit()
    }

    private static func relaunch(appAt url: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        // Wait for current process to exit, then reopen
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; open \"\(url.path)\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", script]
        try? proc.run()

        NSApplication.shared.terminate(nil)
    }

    private func cleanup() {
        isUpdating = false
        downloadProgress = 0
        statusText = ""
        progressObservation = nil
        progressPanel = nil
        progressBar = nil
        statusLabel = nil
    }

    // MARK: - Progress Panel

    private func makeProgressPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        panel.title = "Updating LSLS"
        panel.isReleasedWhenClosed = false
        panel.center()

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 80))

        let label = NSTextField(labelWithString: statusText)
        label.frame = NSRect(x: 20, y: 44, width: 300, height: 18)
        label.font = .systemFont(ofSize: 12)
        container.addSubview(label)

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 16, width: 300, height: 20))
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 1
        bar.isIndeterminate = false
        bar.doubleValue = 0
        container.addSubview(bar)

        panel.contentView = container
        self.progressPanel = panel
        self.progressBar = bar
        self.statusLabel = label

        return panel
    }

    // MARK: - Errors

    enum UpdateError: LocalizedError {
        case mountFailed
        case appNotFound

        var errorDescription: String? {
            switch self {
            case .mountFailed: "Failed to mount the update disk image."
            case .appNotFound: "Could not find the application in the update."
            }
        }
    }

    // MARK: - Private

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Release.self, from: data)
    }

    /// Simple semver comparison: returns true if `remote` is newer than `local`.
    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
