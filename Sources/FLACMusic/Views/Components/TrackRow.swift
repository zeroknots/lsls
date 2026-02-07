import SwiftUI

struct TrackRow: View {
    let trackInfo: TrackInfo
    let showAlbum: Bool
    let isPlaying: Bool
    var onPlay: () -> Void

    init(trackInfo: TrackInfo, showAlbum: Bool = true, isPlaying: Bool = false, onPlay: @escaping () -> Void) {
        self.trackInfo = trackInfo
        self.showAlbum = showAlbum
        self.isPlaying = isPlaying
        self.onPlay = onPlay
    }

    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            Group {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(Color.accentColor)
                } else if let num = trackInfo.track.trackNumber {
                    Text("\(num)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .font(.subheadline.monospacedDigit())

            // Title and artist
            VStack(alignment: .leading, spacing: 2) {
                Text(trackInfo.track.title)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)

                HStack(spacing: 4) {
                    if let artist = trackInfo.artist {
                        Text(artist.name)
                            .foregroundStyle(.secondary)
                    }
                    if showAlbum, let album = trackInfo.album {
                        if trackInfo.artist != nil {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(album.title)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.subheadline)
                .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(TimeFormatter.format(trackInfo.track.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onPlay()
        }
    }
}
