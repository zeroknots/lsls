import Foundation
import Testing

@testable import LSLS

@Suite("PlaylistExporter")
struct PlaylistExporterTests {

    // MARK: - generateM3U8

    @Test("generate M3U8 with tracks")
    func generateWithTracks() {
        let paths = [
            "/Music/Artist/Album/01 - Song One.flac",
            "/Music/Artist/Album/02 - Song Two.flac",
            "/Music/Other/Album/01 - Track.mp3",
        ]
        let content = PlaylistExporter.generateM3U8(trackPaths: paths)

        let lines = content.components(separatedBy: "\n")
        #expect(lines[0] == "#EXTM3U")
        #expect(lines[1] == "/Music/Artist/Album/01 - Song One.flac")
        #expect(lines[2] == "/Music/Artist/Album/02 - Song Two.flac")
        #expect(lines[3] == "/Music/Other/Album/01 - Track.mp3")
    }

    @Test("generate M3U8 starts with header")
    func generateStartsWithHeader() {
        let content = PlaylistExporter.generateM3U8(trackPaths: ["/Music/A/B/01 - C.flac"])
        #expect(content.hasPrefix("#EXTM3U\n"))
    }

    @Test("generate M3U8 ends with newline")
    func generateEndsWithNewline() {
        let content = PlaylistExporter.generateM3U8(trackPaths: ["/Music/A/B/01 - C.flac"])
        #expect(content.hasSuffix("\n"))
    }

    @Test("generate M3U8 empty tracks")
    func generateEmptyTracks() {
        let content = PlaylistExporter.generateM3U8(trackPaths: [])
        #expect(content == "#EXTM3U\n")
    }

    @Test("generate M3U8 preserves path order")
    func generatePreservesOrder() {
        let paths = [
            "/Music/Z/Z/01 - Last.flac",
            "/Music/A/A/01 - First.flac",
        ]
        let content = PlaylistExporter.generateM3U8(trackPaths: paths)
        let lines = content.components(separatedBy: "\n")
        #expect(lines[1] == "/Music/Z/Z/01 - Last.flac")
        #expect(lines[2] == "/Music/A/A/01 - First.flac")
    }

    // MARK: - sanitizedFilename

    @Test("sanitize normal name")
    func sanitizeNormal() {
        #expect(PlaylistExporter.sanitizedFilename("My Playlist") == "My Playlist")
    }

    @Test("sanitize removes illegal characters")
    func sanitizeIllegal() {
        #expect(PlaylistExporter.sanitizedFilename("Best: Hits?") == "Best Hits")
        #expect(PlaylistExporter.sanitizedFilename("AC/DC Mix") == "ACDC Mix")
        #expect(PlaylistExporter.sanitizedFilename("Rock * Roll") == "Rock  Roll")
    }

    @Test("sanitize empty name returns Unknown")
    func sanitizeEmpty() {
        #expect(PlaylistExporter.sanitizedFilename("") == "Unknown")
    }

    @Test("sanitize trims dots and spaces")
    func sanitizeTrimsDots() {
        #expect(PlaylistExporter.sanitizedFilename("...playlist...") == "playlist")
        #expect(PlaylistExporter.sanitizedFilename("  spaced  ") == "spaced")
    }
}
