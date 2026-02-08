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
    var bpm: Double?
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
        let bpm = parseBPM(tags["BPM"] ?? tags["bpm"] ?? tags["TBPM"] ?? tags["tbpm"]
            ?? tags["TEMPO"] ?? tags["tempo"])

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
            fileSize: fileSize,
            bpm: bpm
        )
    }

    private struct ProbeResult {
        var tags: [String: String]
        var duration: TimeInterval
    }

    private static let processTimeout: TimeInterval = 30

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

                    // Kill process if it exceeds timeout
                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + processTimeout)
                    timer.setEventHandler { process.terminate() }
                    timer.resume()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timer.cancel()

                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: MetadataError.processError(process.terminationStatus))
                        return
                    }

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

                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + processTimeout)
                    timer.setEventHandler { process.terminate() }
                    timer.resume()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timer.cancel()

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

    static func parseBPM(_ value: String?) -> Double? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " BPM", with: "")
            .replacingOccurrences(of: " bpm", with: "")
        guard let bpm = Double(cleaned), bpm > 0, bpm < 999 else { return nil }
        return bpm
    }

    private static let aubioPath = "/opt/homebrew/bin/aubio"

    static func detectBPMWithAubio(from url: URL) async -> Double? {
        guard FileManager.default.fileExists(atPath: aubioPath) else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: aubioPath)
                process.arguments = ["tempo", url.path]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()

                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + 60)
                    timer.setEventHandler { process.terminate() }
                    timer.resume()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timer.cancel()

                    guard process.terminationStatus == 0,
                          let output = String(data: data, encoding: .utf8)
                    else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let lines = output.split(separator: "\n")
                        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        .filter { $0 > 0 && $0 < 999 }

                    continuation.resume(returning: lines.last)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func readAudioFormat(from url: URL) async -> AudioFormat? {
        guard !url.absoluteString.hasPrefix("http") else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffprobePath)
                process.arguments = [
                    "-v", "quiet",
                    "-print_format", "json",
                    "-show_streams",
                    "-select_streams", "a:0",
                    url.path,
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()

                    let timer = DispatchSource.makeTimerSource(queue: .global())
                    timer.schedule(deadline: .now() + 5)
                    timer.setEventHandler { process.terminate() }
                    timer.resume()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timer.cancel()

                    guard process.terminationStatus == 0,
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let streams = json["streams"] as? [[String: Any]],
                          let stream = streams.first
                    else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let codecName = stream["codec_name"] as? String ?? "unknown"
                    let sampleRate = Int(stream["sample_rate"] as? String ?? "0") ?? 0
                    let bitDepth = Int(stream["bits_per_raw_sample"] as? String ?? "0") ?? 0
                    let bitRate = Int(stream["bit_rate"] as? String ?? "0") ?? 0
                    let channels = stream["channels"] as? Int ?? 2

                    continuation.resume(returning: AudioFormat(
                        codec: normalizeCodec(codecName),
                        sampleRate: sampleRate,
                        bitDepth: bitDepth > 0 ? bitDepth : nil,
                        bitRate: bitRate > 0 ? bitRate : nil,
                        channels: channels
                    ))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func normalizeCodec(_ raw: String) -> String {
        switch raw.lowercased() {
        case "flac": return "FLAC"
        case "mp3": return "MP3"
        case "aac": return "AAC"
        case "alac": return "ALAC"
        case "vorbis": return "OGG"
        case let s where s.hasPrefix("pcm"): return "WAV"
        default: return raw.uppercased()
        }
    }

    enum MetadataError: Error {
        case parseError
        case processError(Int32)
    }
}
