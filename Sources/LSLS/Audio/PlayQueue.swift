import Foundation

@Observable
final class PlayQueue {
    private(set) var tracks: [TrackInfo] = []
    private(set) var currentIndex: Int = 0
    private var history: [Int] = []

    var current: TrackInfo? {
        guard !tracks.isEmpty, currentIndex >= 0, currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    var upNext: [TrackInfo] {
        guard currentIndex + 1 < tracks.count else { return [] }
        return Array(tracks[(currentIndex + 1)...])
    }

    func setQueue(_ newTracks: [TrackInfo], startingAt track: TrackInfo) {
        tracks = newTracks
        currentIndex = newTracks.firstIndex(where: { $0.track.id == track.track.id }) ?? 0
        history = []
    }

    func next(shuffle: Bool) -> TrackInfo? {
        guard !tracks.isEmpty else { return nil }
        history.append(currentIndex)

        if shuffle {
            var candidates = Array(tracks.indices)
            candidates.removeAll { $0 == currentIndex }
            guard let randomIndex = candidates.randomElement() else { return nil }
            currentIndex = randomIndex
            return tracks[currentIndex]
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < tracks.count else { return nil }
        currentIndex = nextIndex
        return tracks[currentIndex]
    }

    func previous() -> TrackInfo? {
        guard let prevIndex = history.popLast() else { return nil }
        currentIndex = prevIndex
        return tracks[currentIndex]
    }

    func restart() {
        currentIndex = 0
        history = []
    }

    func addNext(_ track: TrackInfo) {
        tracks.insert(track, at: currentIndex + 1)
    }

    func appendToEnd(_ track: TrackInfo) {
        tracks.append(track)
    }

    func remove(at index: Int) {
        guard index >= 0, index < tracks.count else { return }
        tracks.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            currentIndex = min(currentIndex, tracks.count - 1)
        }
    }

    func removeFromUpNext(at upNextIndex: Int) {
        let absoluteIndex = currentIndex + 1 + upNextIndex
        guard absoluteIndex < tracks.count else { return }
        remove(at: absoluteIndex)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let currentTrack = current
        tracks.move(fromOffsets: source, toOffset: destination)
        if let currentTrack, let newIndex = tracks.firstIndex(where: { $0.track.id == currentTrack.track.id }) {
            currentIndex = newIndex
        }
    }
}
