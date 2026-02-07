import Foundation
import Testing

@testable import FLACMusic

@Suite("PlayQueue")
struct PlayQueueTests {

    private func makeTrackInfo(id: Int64, title: String) -> TrackInfo {
        let track = Track(
            id: id,
            filePath: "/test/\(title).flac",
            title: title,
            genre: nil,
            trackNumber: Int(id),
            discNumber: 1,
            duration: 180,
            fileSize: 1000,
            dateAdded: Date()
        )
        return TrackInfo(track: track, album: nil, artist: nil)
    }

    @Test("setQueue sets tracks and finds starting track")
    func setQueue() {
        let queue = PlayQueue()
        let tracks = (1...5).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[2])

        #expect(queue.tracks.count == 5)
        #expect(queue.currentIndex == 2)
        #expect(queue.current?.track.title == "Track 3")
    }

    @Test("next returns next track in sequence")
    func nextSequential() {
        let queue = PlayQueue()
        let tracks = (1...3).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[0])

        let second = queue.next(shuffle: false)
        #expect(second?.track.title == "Track 2")

        let third = queue.next(shuffle: false)
        #expect(third?.track.title == "Track 3")

        let past = queue.next(shuffle: false)
        #expect(past == nil)
    }

    @Test("next with shuffle returns a track")
    func nextShuffle() {
        let queue = PlayQueue()
        let tracks = (1...10).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[0])

        let next = queue.next(shuffle: true)
        #expect(next != nil)
        // Shuffled track should not be the same as current (with 10 tracks, extremely unlikely)
    }

    @Test("previous returns to last track")
    func previous() {
        let queue = PlayQueue()
        let tracks = (1...3).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[0])

        _ = queue.next(shuffle: false) // now at Track 2
        _ = queue.next(shuffle: false) // now at Track 3

        let prev = queue.previous()
        #expect(prev?.track.title == "Track 2")

        let prevPrev = queue.previous()
        #expect(prevPrev?.track.title == "Track 1")
    }

    @Test("previous with no history returns nil")
    func previousNoHistory() {
        let queue = PlayQueue()
        let tracks = [makeTrackInfo(id: 1, title: "Track 1")]

        queue.setQueue(tracks, startingAt: tracks[0])

        #expect(queue.previous() == nil)
    }

    @Test("upNext returns remaining tracks")
    func upNext() {
        let queue = PlayQueue()
        let tracks = (1...5).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[1]) // start at Track 2

        let upcoming = queue.upNext
        #expect(upcoming.count == 3)
        #expect(upcoming[0].track.title == "Track 3")
    }

    @Test("addNext inserts track after current")
    func addNext() {
        let queue = PlayQueue()
        let tracks = (1...3).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[0])

        let inserted = makeTrackInfo(id: 99, title: "Inserted")
        queue.addNext(inserted)

        #expect(queue.tracks.count == 4)
        let next = queue.next(shuffle: false)
        #expect(next?.track.title == "Inserted")
    }

    @Test("restart resets to beginning")
    func restart() {
        let queue = PlayQueue()
        let tracks = (1...3).map { makeTrackInfo(id: Int64($0), title: "Track \($0)") }

        queue.setQueue(tracks, startingAt: tracks[0])
        _ = queue.next(shuffle: false)
        _ = queue.next(shuffle: false)

        queue.restart()

        #expect(queue.currentIndex == 0)
        #expect(queue.current?.track.title == "Track 1")
    }

    @Test("empty queue returns nil for current and next")
    func emptyQueue() {
        let queue = PlayQueue()

        #expect(queue.current == nil)
        #expect(queue.next(shuffle: false) == nil)
        #expect(queue.upNext.isEmpty)
    }
}
