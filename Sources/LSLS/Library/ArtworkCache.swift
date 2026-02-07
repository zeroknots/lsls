import AppKit
import Foundation

@MainActor
@Observable
final class ArtworkCache {
    static let shared = ArtworkCache()

    private var memoryCache: [String: NSImage] = [:]
    private let cacheDir: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDir = appSupport.appendingPathComponent("LSLS/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func artwork(for album: Album) -> NSImage? {
        guard let albumId = album.id else { return nil }
        let key = "album-\(albumId)"

        if let cached = memoryCache[key] {
            return cached
        }

        if let path = album.artworkPath,
           let image = NSImage(contentsOfFile: path) {
            memoryCache[key] = image
            return image
        }

        return nil
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
            let key = "album-\(albumId)"
            memoryCache[key] = image
            return url.path
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }

    func clearMemoryCache() {
        memoryCache.removeAll()
    }
}
