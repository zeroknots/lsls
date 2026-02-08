import Foundation
import Testing

@testable import LSLS

@Suite("MetadataReader")
struct MetadataReaderTests {

    // MARK: - parseTrackNumber

    @Test("parseTrackNumber with simple integer")
    func parseTrackNumberSimple() {
        #expect(MetadataReader.parseTrackNumber("1") == 1)
        #expect(MetadataReader.parseTrackNumber("12") == 12)
        #expect(MetadataReader.parseTrackNumber("0") == 0)
    }

    @Test("parseTrackNumber with slash format like 1/6")
    func parseTrackNumberSlash() {
        #expect(MetadataReader.parseTrackNumber("1/6") == 1)
        #expect(MetadataReader.parseTrackNumber("3/12") == 3)
        #expect(MetadataReader.parseTrackNumber("10/10") == 10)
    }

    @Test("parseTrackNumber with nil")
    func parseTrackNumberNil() {
        #expect(MetadataReader.parseTrackNumber(nil) == nil)
    }

    @Test("parseTrackNumber with invalid input")
    func parseTrackNumberInvalid() {
        #expect(MetadataReader.parseTrackNumber("abc") == nil)
        #expect(MetadataReader.parseTrackNumber("") == nil)
    }

    // MARK: - parseYear

    @Test("parseYear with four-digit year")
    func parseYearSimple() {
        #expect(MetadataReader.parseYear("1992") == 1992)
        #expect(MetadataReader.parseYear("2024") == 2024)
        #expect(MetadataReader.parseYear("1901") == 1901)
        #expect(MetadataReader.parseYear("2099") == 2099)
    }

    @Test("parseYear with date string")
    func parseYearFromDate() {
        #expect(MetadataReader.parseYear("1992-01-15") == 1992)
        #expect(MetadataReader.parseYear("2024-12-31") == 2024)
    }

    @Test("parseYear with nil")
    func parseYearNil() {
        #expect(MetadataReader.parseYear(nil) == nil)
    }

    @Test("parseYear with out-of-range values")
    func parseYearOutOfRange() {
        #expect(MetadataReader.parseYear("1899") == nil)
        #expect(MetadataReader.parseYear("2100") == nil)
        #expect(MetadataReader.parseYear("1900") == nil)
    }

    @Test("parseYear with invalid input")
    func parseYearInvalid() {
        #expect(MetadataReader.parseYear("abc") == nil)
        #expect(MetadataReader.parseYear("") == nil)
        #expect(MetadataReader.parseYear("99") == nil)
    }

    // MARK: - supportedExtensions

    @Test("supportedExtensions contains expected formats")
    func supportedExtensions() {
        let expected: Set<String> = ["flac", "mp3", "m4a", "aac", "wav", "aiff", "alac", "ogg"]
        #expect(MetadataReader.supportedExtensions == expected)
    }

    // MARK: - Integration: read from generated FLAC file

    @Test("read extracts metadata from generated FLAC via ffprobe")
    func readGeneratedFLAC() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(
            in: tmpDir,
            title: "Sweat",
            artist: "TOOL",
            album: "Opiate",
            year: "1992",
            track: "1/6",
            genre: "Metal"
        )

        let metadata = try await MetadataReader.read(from: flac)

        #expect(metadata.title == "Sweat")
        #expect(metadata.artist == "TOOL")
        #expect(metadata.albumTitle == "Opiate")
        #expect(metadata.genre == "Metal")
        #expect(metadata.trackNumber == 1)
        #expect(metadata.year == 1992)
        #expect(metadata.duration > 0)
        #expect(metadata.fileSize > 0)
    }

    @Test("extractArtwork returns embedded cover art from generated FLAC")
    func extractArtwork() async throws {
        guard TestFixtures.hasFFmpeg else { return }

        let tmpDir = try TestFixtures.createTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let flac = try TestFixtures.generateFlac(in: tmpDir, withArtwork: true)

        let data = await MetadataReader.extractArtwork(from: flac)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 100)
    }
}
