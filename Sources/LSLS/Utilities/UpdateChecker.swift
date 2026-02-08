import AppKit
import Foundation

@MainActor
@Observable
final class UpdateChecker {
    private static let repo = "zeroknots/flacmusic"
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    var updateAvailable: Release?

    struct Release: Decodable, Sendable {
        let tagName: String
        let htmlUrl: String
        let body: String?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case body
        }

        var version: String {
            tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        }
    }

    func checkForUpdates(silent: Bool = true) {
        Task {
            guard let release = try? await fetchLatestRelease() else {
                if !silent { showUpToDateAlert() }
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

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "LSLS \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showUpdateAlert(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "LSLS \(release.version) Available"
        alert.informativeText = release.body ?? "A new version is available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
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
