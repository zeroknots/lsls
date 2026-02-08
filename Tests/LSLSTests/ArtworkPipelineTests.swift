import AppKit
import Foundation
import GRDB
import Testing

@testable import LSLS

@Suite("Artwork Pipeline")
struct ArtworkPipelineTests {

    private static let testFile = URL(
        fileURLWithPath:
            "/Volumes/media/music/TOOL DISCOGRAPHY [24 96] REMASTERED - QOBUZ - MMXX/TOOL [24 96] MMXX/[1992] OPIATE EP/01 - Sweat.flac"
    )

    private static var hasTestFile: Bool {
        FileManager.default.fileExists(atPath: testFile.path)
    }

    private static var hasFFmpeg: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffmpeg")
    }

    // MARK: - extractArtwork

    @Test("extractArtwork returns valid JPEG data")
    func extractArtworkData() async {
        guard Self.hasTestFile else { return }

        let data = await MetadataReader.extractArtwork(from: Self.testFile)
        #expect(data != nil)
        guard let data else { return }

        #expect(data.count > 1000, "Artwork should be at least 1KB, got \(data.count)")

        // Verify JPEG header (FFD8)
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xD8)
    }

    @Test("extractArtwork completes within timeout")
    func extractArtworkTiming() async {
        guard Self.hasTestFile else { return }

        let start = Date()
        _ = await MetadataReader.extractArtwork(from: Self.testFile)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 15, "Extraction took \(String(format: "%.1f", elapsed))s — should be under 15s")
    }

    @Test("extractArtwork returns nil for file without artwork")
    func extractArtworkNoArt() async {
        guard Self.hasFFmpeg else { return }

        // Create a tiny WAV file with no artwork
        let tmpWav = FileManager.default.temporaryDirectory
            .appendingPathComponent("lsls-test-noart-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: tmpWav) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        process.arguments = [
            "-v", "quiet", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.1",
            "-y", tmpWav.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return }

        let data = await MetadataReader.extractArtwork(from: tmpWav)
        #expect(data == nil)
    }

    @Test("extractArtwork returns nil for nonexistent file")
    func extractArtworkMissingFile() async {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID()).flac")
        let data = await MetadataReader.extractArtwork(from: fakeURL)
        #expect(data == nil)
    }

    // MARK: - Full save pipeline

    @Test("extracted artwork can be saved via ArtworkCache")
    @MainActor
    func extractAndSave() async {
        guard Self.hasTestFile else { return }

        let data = await MetadataReader.extractArtwork(from: Self.testFile)
        #expect(data != nil)
        guard let data else { return }

        let image = NSImage(data: data)
        #expect(image != nil)
        guard let image else { return }

        let albumId: Int64 = 99990
        let savedPath = ArtworkCache.shared.saveArtwork(image, for: albumId)
        #expect(savedPath != nil)

        guard let savedPath else { return }
        defer { try? FileManager.default.removeItem(atPath: savedPath) }

        // Verify saved file is valid
        #expect(FileManager.default.fileExists(atPath: savedPath))
        let savedData = try? Data(contentsOf: URL(fileURLWithPath: savedPath))
        #expect((savedData?.count ?? 0) > 1000)

        // Verify it's in the memory cache
        let album = Album(id: albumId, title: "Pipeline Test", artworkPath: savedPath)
        let cached = ArtworkCache.shared.cachedArtwork(for: album)
        #expect(cached != nil)
    }

    @Test("artwork round-trip: save then load from disk")
    @MainActor
    func saveAndReload() async {
        guard Self.hasTestFile else { return }

        let data = await MetadataReader.extractArtwork(from: Self.testFile)
        guard let data, let image = NSImage(data: data) else { return }

        let albumId: Int64 = 99989
        let savedPath = ArtworkCache.shared.saveArtwork(image, for: albumId)
        guard let savedPath else { return }
        defer { try? FileManager.default.removeItem(atPath: savedPath) }

        // Clear memory cache to force disk reload
        ArtworkCache.shared.clearMemoryCache()

        let album = Album(id: albumId, title: "Reload Test", artworkPath: savedPath)
        #expect(ArtworkCache.shared.cachedArtwork(for: album) == nil)

        let reloaded = await ArtworkCache.shared.loadArtwork(for: album)
        #expect(reloaded != nil)
        #expect(reloaded!.size.width > 0)
    }
}
