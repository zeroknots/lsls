import Foundation

struct RockboxChangelogEntry {
    let filePath: String
    var playCount: Int
    var rating: Int
    var playTime: Int
    var lastPlayed: Date?
}

enum RockboxChangelog {
    private static let header = "## Changelog version 1"

    static func parse(_ content: String) -> [RockboxChangelogEntry] {
        var entries: [RockboxChangelogEntry] = []
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("##") { continue }

            let tags = parseTags(trimmed)
            guard let filePath = tags["filename"], !filePath.isEmpty else { continue }

            let entry = RockboxChangelogEntry(
                filePath: filePath,
                playCount: Int(tags["playcount"] ?? "") ?? 0,
                rating: Int(tags["rating"] ?? "") ?? 0,
                playTime: Int(tags["playtime"] ?? "") ?? 0,
                lastPlayed: tags["lastplayed"].flatMap { Int($0) }.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            )
            entries.append(entry)
        }

        return entries
    }

    static func serialize(_ entries: [RockboxChangelogEntry]) -> String {
        var lines: [String] = [header]

        for entry in entries {
            var parts: [String] = []
            parts.append("filename=\"\(escapeValue(entry.filePath))\"")
            parts.append("playcount=\"\(entry.playCount)\"")
            parts.append("rating=\"\(entry.rating)\"")
            parts.append("playtime=\"\(entry.playTime)\"")
            let lastPlayedTs = entry.lastPlayed.map { Int($0.timeIntervalSince1970) } ?? 0
            parts.append("lastplayed=\"\(lastPlayedTs)\"")
            lines.append(parts.joined(separator: " "))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func parseTags(_ line: String) -> [String: String] {
        var tags: [String: String] = [:]
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // Skip whitespace
            remaining = remaining.drop(while: { $0 == " " })
            guard !remaining.isEmpty else { break }

            // Find '='
            guard let eqIndex = remaining.firstIndex(of: "=") else { break }
            let key = String(remaining[remaining.startIndex..<eqIndex])
            remaining = remaining[remaining.index(after: eqIndex)...]

            // Expect opening quote
            guard remaining.first == "\"" else { break }
            remaining = remaining[remaining.index(after: remaining.startIndex)...]

            // Read until unescaped closing quote
            var value = ""
            var escaped = false
            while !remaining.isEmpty {
                let ch = remaining.first!
                remaining = remaining[remaining.index(after: remaining.startIndex)...]

                if escaped {
                    switch ch {
                    case "n": value.append("\n")
                    default: value.append(ch) // handles \" and \\
                    }
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    break
                } else {
                    value.append(ch)
                }
            }

            tags[key] = value
        }

        return tags
    }

    private static func escapeValue(_ value: String) -> String {
        var result = ""
        for ch in value {
            switch ch {
            case "\"": result.append("\\\"")
            case "\\": result.append("\\\\")
            case "\n": result.append("\\n")
            default: result.append(ch)
            }
        }
        return result
    }
}
