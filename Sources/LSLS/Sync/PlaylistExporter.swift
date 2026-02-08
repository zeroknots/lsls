import Foundation

enum PlaylistExporter {
    static func generateM3U8(trackPaths: [String]) -> String {
        var lines = ["#EXTM3U"]
        lines.append(contentsOf: trackPaths)
        return lines.joined(separator: "\n") + "\n"
    }

    static func sanitizedFilename(_ name: String) -> String {
        SyncPathBuilder.sanitize(name)
    }
}
