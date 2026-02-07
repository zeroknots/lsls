import Foundation

struct TrackMetadata: Sendable {
    var title: String
    var artist: String?
    var albumTitle: String?
    var genre: String?
    var trackNumber: Int?
    var discNumber: Int?
    var year: Int?
    var duration: TimeInterval
    var artworkData: Data?
    var fileSize: Int64
}

enum MetadataReader {
    static let supportedExtensions: Set<String> = ["flac", "mp3", "m4a", "aac", "wav", "aiff", "alac", "ogg"]

    private static let ffprobePath = "/opt/homebrew/bin/ffprobe"
    private static let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    static func read(from url: URL) async throws -> TrackMetadata {
        let probeResult = try await runFFProbe(for: url)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let tags = probeResult.tags
        let duration = probeResult.duration

        let title = tags["TITLE"] ?? tags["title"]
            ?? url.deletingPathExtension().lastPathComponent
        let artist = tags["ARTIST"] ?? tags["artist"]
            ?? tags["album_artist"] ?? tags["ALBUMARTIST"]
        let albumTitle = tags["ALBUM"] ?? tags["album"]
        let genre = tags["GENRE"] ?? tags["genre"]

        let trackNumber = parseTrackNumber(tags["track"] ?? tags["TRACK"] ?? tags["TRACKNUMBER"] ?? tags["tracknumber"])
        let discNumber = parseTrackNumber(tags["disc"] ?? tags["DISC"] ?? tags["DISCNUMBER"] ?? tags["discnumber"])
        let year = parseYear(tags["DATE"] ?? tags["date"] ?? tags["YEAR"] ?? tags["year"])

        return TrackMetadata(
            title: title,
            artist: artist,
            albumTitle: albumTitle,
            genre: genre,
            trackNumber: trackNumber,
            discNumber: discNumber,
            year: year,
            duration: duration,
            artworkData: nil,
            fileSize: fileSize
        )
    }

    private struct ProbeResult {
        var tags: [String: String]
        var duration: TimeInterval
    }

    private static func runFFProbe(for url: URL) async throws -> ProbeResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffprobePath)
                process.arguments = [
                    "-v", "quiet",
                    "-print_format", "json",
                    "-show_format",
                    url.path,
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let format = json["format"] as? [String: Any]
                    else {
                        continuation.resume(throwing: MetadataError.parseError)
                        return
                    }

                    let tags = format["tags"] as? [String: String] ?? [:]
                    let duration = Double(format["duration"] as? String ?? "0") ?? 0

                    continuation.resume(returning: ProbeResult(tags: tags, duration: duration))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func extractArtwork(from url: URL) async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffmpegPath)
                process.arguments = [
                    "-v", "quiet",
                    "-i", url.path,
                    "-an",
                    "-vcodec", "copy",
                    "-f", "image2pipe",
                    "-",
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    continuation.resume(returning: data.isEmpty ? nil : data)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func parseTrackNumber(_ value: String?) -> Int? {
        guard let value else { return nil }
        // Handle "1/6" format
        let parts = value.split(separator: "/")
        if let first = parts.first, let num = Int(first) {
            return num
        }
        return Int(value)
    }

    static func parseYear(_ value: String?) -> Int? {
        guard let value else { return nil }
        let yearStr = String(value.prefix(4))
        if let year = Int(yearStr), year > 1900, year < 2100 {
            return year
        }
        return nil
    }

    enum MetadataError: Error {
        case parseError
    }
}
