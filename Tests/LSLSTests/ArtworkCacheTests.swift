import AppKit
import Foundation
import Testing

@testable import LSLS

@Suite("ArtworkCache")
@MainActor
struct ArtworkCacheTests {

    private static func makeTestImage(width: Int = 100, height: Int = 100, color: NSColor = .red) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.drawSwatch(in: NSRect(x: 0, y: 0, width: width, height: height))
        image.unlockFocus()
        return image
    }

    @Test("saveArtwork writes JPEG to disk and returns path")
    func saveArtwork() {
        let cache = ArtworkCache.shared
        let testImage = Self.makeTestImage()
        let albumId: Int64 = 99999

        let savedPath = cache.saveArtwork(testImage, for: albumId)
        #expect(savedPath != nil)

        guard let path = savedPath else { return }
        #expect(path.hasSuffix("album-99999.jpg"))
        #expect(FileManager.default.fileExists(atPath: path))

        // Verify file is valid JPEG
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        #expect(data != nil)
        #expect((data?.count ?? 0) > 100)

        // Cleanup
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("cachedArtwork returns image after save")
    func cachedArtworkAfterSave() {
        let cache = ArtworkCache.shared
        let testImage = Self.makeTestImage(color: .blue)
        let albumId: Int64 = 99998

        // Save populates the memory cache
        let savedPath = cache.saveArtwork(testImage, for: albumId)
        #expect(savedPath != nil)

        // Synchronous cache lookup should find it
        let album = Album(id: albumId, title: "Test Album", artworkPath: savedPath)
        let cached = cache.cachedArtwork(for: album)
        #expect(cached != nil)

        // Cleanup
        if let path = savedPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test("cachedArtwork returns nil for unknown album")
    func cachedArtworkMiss() {
        let cache = ArtworkCache.shared
        let album = Album(id: 88888, title: "Nonexistent", artworkPath: nil)
        let cached = cache.cachedArtwork(for: album)
        #expect(cached == nil)
    }

    @Test("cachedArtwork returns nil when album has no id")
    func cachedArtworkNoId() {
        let cache = ArtworkCache.shared
        let album = Album(id: nil, title: "No ID", artworkPath: nil)
        let cached = cache.cachedArtwork(for: album)
        #expect(cached == nil)
    }

    @Test("clearMemoryCache removes cached images")
    func clearMemoryCache() {
        let cache = ArtworkCache.shared
        let testImage = Self.makeTestImage(color: .green)
        let albumId: Int64 = 99997

        let savedPath = cache.saveArtwork(testImage, for: albumId)
        #expect(savedPath != nil)

        let album = Album(id: albumId, title: "Test", artworkPath: savedPath)
        #expect(cache.cachedArtwork(for: album) != nil)

        cache.clearMemoryCache()
        #expect(cache.cachedArtwork(for: album) == nil)

        if let path = savedPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test("loadArtwork reads from disk when not in memory cache")
    func loadArtworkFromDisk() async {
        let cache = ArtworkCache.shared
        let testImage = Self.makeTestImage(width: 200, height: 200, color: .purple)
        let albumId: Int64 = 99996

        let savedPath = cache.saveArtwork(testImage, for: albumId)
        #expect(savedPath != nil)

        // Clear memory cache to force disk read
        cache.clearMemoryCache()

        let album = Album(id: albumId, title: "Disk Test", artworkPath: savedPath)
        #expect(cache.cachedArtwork(for: album) == nil)

        let loaded = await cache.loadArtwork(for: album)
        #expect(loaded != nil)
        #expect(loaded!.size.width > 0)

        // Should now be in memory cache
        #expect(cache.cachedArtwork(for: album) != nil)

        if let path = savedPath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    @Test("loadArtwork returns nil for album without artworkPath")
    func loadArtworkNoPath() async {
        let cache = ArtworkCache.shared
        let album = Album(id: 88887, title: "No Path", artworkPath: nil)
        let loaded = await cache.loadArtwork(for: album)
        #expect(loaded == nil)
    }

    @Test("loadArtwork returns nil for nonexistent file")
    func loadArtworkMissingFile() async {
        let cache = ArtworkCache.shared
        let album = Album(id: 88886, title: "Missing", artworkPath: "/nonexistent/path.jpg")
        let loaded = await cache.loadArtwork(for: album)
        #expect(loaded == nil)
    }
}
