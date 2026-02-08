import Foundation
import Testing

@testable import LSLS

@Suite("RockboxChangelog")
struct RockboxChangelogTests {

    // MARK: - Parse

    @Test("parse empty string returns empty array")
    func parseEmpty() {
        let entries = RockboxChangelog.parse("")
        #expect(entries.isEmpty)
    }

    @Test("parse header only returns empty array")
    func parseHeaderOnly() {
        let entries = RockboxChangelog.parse("## Changelog version 1\n")
        #expect(entries.isEmpty)
    }

    @Test("parse single entry")
    func parseSingleEntry() {
        let content = """
        ## Changelog version 1
        filename="/Music/Artist/Album/01 - Song.flac" playcount="5" rating="8" playtime="1200000" lastplayed="1700000000"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].filePath == "/Music/Artist/Album/01 - Song.flac")
        #expect(entries[0].playCount == 5)
        #expect(entries[0].rating == 8)
        #expect(entries[0].playTime == 1200000)
        #expect(entries[0].lastPlayed == Date(timeIntervalSince1970: 1700000000))
    }

    @Test("parse multiple entries")
    func parseMultipleEntries() {
        let content = """
        ## Changelog version 1
        filename="/Music/A/B/01 - One.flac" playcount="3" rating="10" playtime="600000" lastplayed="1700000000"
        filename="/Music/C/D/02 - Two.mp3" playcount="0" rating="0" playtime="0" lastplayed="0"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 2)
        #expect(entries[0].filePath == "/Music/A/B/01 - One.flac")
        #expect(entries[1].filePath == "/Music/C/D/02 - Two.mp3")
        #expect(entries[1].playCount == 0)
        #expect(entries[1].lastPlayed == Date(timeIntervalSince1970: 0))
    }

    @Test("parse entry with escaped quotes in path")
    func parseEscapedQuotes() {
        let content = """
        filename="/Music/Artist/The \\\"Best\\\" Album/01 - Song.flac" playcount="1" rating="0" playtime="0" lastplayed="0"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].filePath == "/Music/Artist/The \"Best\" Album/01 - Song.flac")
    }

    @Test("parse entry with escaped backslash")
    func parseEscapedBackslash() {
        let content = """
        filename="/Music/AC\\\\DC/Album/01 - Song.flac" playcount="2" rating="0" playtime="0" lastplayed="0"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].filePath == "/Music/AC\\DC/Album/01 - Song.flac")
    }

    @Test("parse skips lines without filename")
    func parseSkipsNoFilename() {
        let content = """
        ## Changelog version 1
        playcount="5" rating="8"
        filename="/Music/A/B/01 - Valid.flac" playcount="1" rating="0" playtime="0" lastplayed="0"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].filePath == "/Music/A/B/01 - Valid.flac")
    }

    @Test("parse handles missing optional fields")
    func parseMissingFields() {
        let content = """
        filename="/Music/A/B/01 - Song.flac"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].playCount == 0)
        #expect(entries[0].rating == 0)
        #expect(entries[0].playTime == 0)
        #expect(entries[0].lastPlayed == nil)
    }

    @Test("parse handles unicode paths")
    func parseUnicode() {
        let content = """
        filename="/Music/Queensr\u{00FF}che/Album/01 - Song.flac" playcount="3" rating="0" playtime="0" lastplayed="0"
        """
        let entries = RockboxChangelog.parse(content)
        #expect(entries.count == 1)
        #expect(entries[0].filePath.contains("Queensr"))
    }

    // MARK: - Serialize

    @Test("serialize empty array")
    func serializeEmpty() {
        let content = RockboxChangelog.serialize([])
        #expect(content == "## Changelog version 1\n")
    }

    @Test("serialize single entry")
    func serializeSingleEntry() {
        let entry = RockboxChangelogEntry(
            filePath: "/Music/Artist/Album/01 - Song.flac",
            playCount: 5,
            rating: 8,
            playTime: 1200000,
            lastPlayed: Date(timeIntervalSince1970: 1700000000)
        )
        let content = RockboxChangelog.serialize([entry])
        #expect(content.contains("## Changelog version 1"))
        #expect(content.contains("filename=\"/Music/Artist/Album/01 - Song.flac\""))
        #expect(content.contains("playcount=\"5\""))
        #expect(content.contains("rating=\"8\""))
        #expect(content.contains("playtime=\"1200000\""))
        #expect(content.contains("lastplayed=\"1700000000\""))
    }

    @Test("serialize escapes quotes in path")
    func serializeEscapesQuotes() {
        let entry = RockboxChangelogEntry(
            filePath: "/Music/The \"Best\"/01 - Song.flac",
            playCount: 0,
            rating: 0,
            playTime: 0,
            lastPlayed: nil
        )
        let content = RockboxChangelog.serialize([entry])
        #expect(content.contains("filename=\"/Music/The \\\"Best\\\"/01 - Song.flac\""))
    }

    @Test("serialize nil lastPlayed writes 0")
    func serializeNilLastPlayed() {
        let entry = RockboxChangelogEntry(
            filePath: "/Music/A/B/01 - Song.flac",
            playCount: 0,
            rating: 0,
            playTime: 0,
            lastPlayed: nil
        )
        let content = RockboxChangelog.serialize([entry])
        #expect(content.contains("lastplayed=\"0\""))
    }

    // MARK: - Round-trip

    @Test("round-trip preserves data")
    func roundTrip() {
        let original = [
            RockboxChangelogEntry(
                filePath: "/Music/Pink Floyd/The Wall/01 - In The Flesh.flac",
                playCount: 42,
                rating: 10,
                playTime: 5040000,
                lastPlayed: Date(timeIntervalSince1970: 1700000000)
            ),
            RockboxChangelogEntry(
                filePath: "/Music/Bowie/Ziggy/01 - Five Years.flac",
                playCount: 7,
                rating: 6,
                playTime: 2100000,
                lastPlayed: Date(timeIntervalSince1970: 1690000000)
            ),
        ]

        let serialized = RockboxChangelog.serialize(original)
        let parsed = RockboxChangelog.parse(serialized)

        #expect(parsed.count == 2)
        #expect(parsed[0].filePath == original[0].filePath)
        #expect(parsed[0].playCount == original[0].playCount)
        #expect(parsed[0].rating == original[0].rating)
        #expect(parsed[0].playTime == original[0].playTime)
        #expect(parsed[0].lastPlayed == original[0].lastPlayed)
        #expect(parsed[1].filePath == original[1].filePath)
        #expect(parsed[1].playCount == original[1].playCount)
        #expect(parsed[1].rating == original[1].rating)
    }

    @Test("round-trip with special characters in path")
    func roundTripSpecialChars() {
        let original = RockboxChangelogEntry(
            filePath: "/Music/Guns N' Roses/Use Your Illusion/01 - Right Next Door to Hell.flac",
            playCount: 3,
            rating: 0,
            playTime: 900000,
            lastPlayed: Date(timeIntervalSince1970: 1700000000)
        )

        let serialized = RockboxChangelog.serialize([original])
        let parsed = RockboxChangelog.parse(serialized)

        #expect(parsed.count == 1)
        #expect(parsed[0].filePath == original.filePath)
    }
}
