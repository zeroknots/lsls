import Foundation
import Testing

@testable import LSLS

@Suite("Folder Artwork Lookup")
struct FolderArtworkTests {

    private static func createTempFolder() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("lsls-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    private static func writeTestImage(to url: URL) throws {
        // Minimal valid JPEG (2x2 red pixel)
        let jpegHeader: [UInt8] = [
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
        ]
        try Data(jpegHeader).write(to: url)
    }

    @Test("finds cover.jpg in folder")
    func findCoverJpg() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let coverFile = folder.appendingPathComponent("cover.jpg")
        try Self.writeTestImage(to: coverFile)

        let dummyTrack = folder.appendingPathComponent("01 - Song.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 0)
    }

    @Test("finds folder.jpg in folder")
    func findFolderJpg() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let coverFile = folder.appendingPathComponent("folder.jpg")
        try Self.writeTestImage(to: coverFile)

        let dummyTrack = folder.appendingPathComponent("track.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data != nil)
    }

    @Test("finds front.png in folder")
    func findFrontPng() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let coverFile = folder.appendingPathComponent("front.png")
        try Self.writeTestImage(to: coverFile)

        let dummyTrack = folder.appendingPathComponent("track.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data != nil)
    }

    @Test("is case-insensitive for artwork filenames")
    func caseInsensitive() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let coverFile = folder.appendingPathComponent("Cover.JPG")
        try Self.writeTestImage(to: coverFile)

        let dummyTrack = folder.appendingPathComponent("song.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data != nil)
    }

    @Test("returns nil for non-standard artwork names")
    func nonStandardNames() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        // These should NOT be recognized as artwork
        let oddFile = folder.appendingPathComponent("I.jpg")
        try Self.writeTestImage(to: oddFile)

        let dummyTrack = folder.appendingPathComponent("track.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data == nil)
    }

    @Test("returns nil for empty folder")
    func emptyFolder() throws {
        let folder = try Self.createTempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let dummyTrack = folder.appendingPathComponent("track.flac")
        FileManager.default.createFile(atPath: dummyTrack.path, contents: nil)

        let data = LibraryManager.findFolderArtworkData(for: dummyTrack)
        #expect(data == nil)
    }

    @Test("returns nil for nonexistent folder")
    func nonexistentFolder() {
        let fakePath = URL(fileURLWithPath: "/tmp/nonexistent-lsls-\(UUID())/track.flac")
        let data = LibraryManager.findFolderArtworkData(for: fakePath)
        #expect(data == nil)
    }
}
