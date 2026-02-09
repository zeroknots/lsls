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

    /// Max pixel dimension to downsample artwork to (2x retina of largest display size ~320pt).
    private nonisolated static let maxPixelSize: CGFloat = 640

    /// Loads artwork asynchronously, downsampling to display size off the main thread.
    func loadArtwork(for album: Album) async -> NSImage? {
        guard let albumId = album.id else { return nil }
        let key = "album-\(albumId)" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let path = album.artworkPath else { return nil }
        let maxSize = Self.maxPixelSize

        // Downsample on a background thread, returning raw Data to cross isolation boundary
        let data: Data? = await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }

            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
                return nil
            }

            let rep = NSBitmapImageRep(cgImage: cgImage)
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
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
