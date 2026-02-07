import Foundation

enum SyncPathBuilder {
    private static let illegalCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")

    static func sanitize(_ name: String) -> String {
        let filtered = name.unicodeScalars
            .filter { !illegalCharacters.contains($0) }
            .map { Character($0) }
        let result = String(filtered)
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return result.isEmpty ? "Unknown" : result
    }

    static func devicePath(
        artistName: String?,
        albumTitle: String?,
        trackNumber: Int?,
        discNumber: Int?,
        trackTitle: String,
        fileExtension: String
    ) -> String {
        let artist = sanitize(artistName ?? "Unknown Artist")
        let album = sanitize(albumTitle ?? "Unknown Album")
        let title = sanitize(trackTitle)
        let ext = fileExtension.lowercased()

        let trackNum: String
        if let disc = discNumber, disc > 1, let num = trackNumber {
            trackNum = String(format: "%d%02d", disc, num)
        } else if let num = trackNumber {
            trackNum = String(format: "%02d", num)
        } else {
            trackNum = "00"
        }

        let filename = "\(trackNum) - \(title).\(ext)"
        return "Music/\(artist)/\(album)/\(filename)"
    }

    static func artworkPath(
        artistName: String?,
        albumTitle: String?
    ) -> String {
        let artist = sanitize(artistName ?? "Unknown Artist")
        let album = sanitize(albumTitle ?? "Unknown Album")
        return "Music/\(artist)/\(album)/cover.jpg"
    }
}
