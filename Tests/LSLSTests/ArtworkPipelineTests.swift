import AppKit
import Foundation
import GRDB
import Testing

@testable import LSLS

@Suite("Artwork Pipeline")
struct ArtworkPipelineTests {

    // MARK: - extractArtwork

    @Test("extractArtwork returns valid JPEG data")
    func extractArtworkData() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: true)

        let data = await MetadataReader.extractArtwork(from: flac)
        #expect(data != nil)
        guard let data else { return }

        #expect(data.count > 100, "Artwork should be at least 100 bytes, got \(data.count)")

        // Verify JPEG header (FFD8)
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xD8)
    }

    @Test("extractArtwork completes within timeout")
    func extractArtworkTiming() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: true)

        let start = Date()
        _ = await MetadataReader.extractArtwork(from: flac)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 15, "Extraction took \(String(format: "%.1f", elapsed))s — should be under 15s")
    }

    @Test("extractArtwork returns nil for file without artwork")
    func extractArtworkNoArt() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: false)

        let data = await MetadataReader.extractArtwork(from: flac)
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
    func extractAndSave() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: true)

        let data = await MetadataReader.extractArtwork(from: flac)
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
        #expect((savedData?.count ?? 0) > 100)

        // Verify it's in the memory cache
        let album = Album(id: albumId, title: "Pipeline Test", artworkPath: savedPath)
        let cached = ArtworkCache.shared.cachedArtwork(for: album)
        #expect(cached != nil)
    }

    @Test("artwork round-trip: save then load from disk")
    @MainActor
    func saveAndReload() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: true)

        let data = await MetadataReader.extractArtwork(from: flac)
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
