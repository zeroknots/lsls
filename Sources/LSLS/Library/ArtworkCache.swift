import AppKit
import Foundation

@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private let cache = NSCache<NSString, NSImage>()
    private let cacheDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("LSLS/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        cache.countLimit = 200
    }

    /// Synchronous cache-only lookup. No disk I/O — safe to call from view body.
    func cachedArtwork(for album: Album) -> NSImage? {
        guard let albumId = album.id else { return nil }
        return cache.object(forKey: "album-\(albumId)" as NSString)
    }

    /// Loads artwork asynchronously, reading file data off the main thread.
    func loadArtwork(for album: Album) async -> NSImage? {
        guard let albumId = album.id else { return nil }
        let key = "album-\(albumId)" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let path = album.artworkPath else { return nil }

        let data: Data? = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: URL(fileURLWithPath: path))
        }.value

        guard let data, let image = NSImage(data: data) else { return nil }

        cache.setObject(image, forKey: key)
        return image
    }

    func saveArtwork(_ image: NSImage, for albumId: Int64) -> String? {
        let filename = "album-\(albumId).jpg"
        let url = cacheDir.appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return nil
        }

        do {
            try jpegData.write(to: url)
            let key = "album-\(albumId)" as NSString
            cache.setObject(image, forKey: key)
            return url.path
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }

    func clearMemoryCache() {
        cache.removeAllObjects()
    }
}
