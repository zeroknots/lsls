import SwiftUI

struct TrackRow: View {
    let trackInfo: TrackInfo
    let showAlbum: Bool
    let isPlaying: Bool
    var onPlay: () -> Void
    var onSyncToggle: (() -> Void)?
    var isInSyncList: Bool
    var playlists: [Playlist]
    var onAddToPlaylist: ((Playlist) -> Void)?
    var onAddToQueue: (() -> Void)?
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    init(trackInfo: TrackInfo, showAlbum: Bool = true, isPlaying: Bool = false, isInSyncList: Bool = false, playlists: [Playlist] = [], onPlay: @escaping () -> Void, onAddToQueue: (() -> Void)? = nil, onSyncToggle: (() -> Void)? = nil, onAddToPlaylist: ((Playlist) -> Void)? = nil, onDelete: (() -> Void)? = nil, onEdit: (() -> Void)? = nil) {
        self.trackInfo = trackInfo
        self.showAlbum = showAlbum
        self.isPlaying = isPlaying
        self.isInSyncList = isInSyncList
        self.playlists = playlists
        self.onPlay = onPlay
        self.onAddToQueue = onAddToQueue
        self.onSyncToggle = onSyncToggle
        self.onAddToPlaylist = onAddToPlaylist
        self.onDelete = onDelete
        self.onEdit = onEdit
    }

    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            Group {
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(colors.accent)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .foregroundStyle(colors.textSecondary)
                } else if let num = trackInfo.track.trackNumber {
                    Text("\(num)")
                        .foregroundStyle(colors.textTertiary)
                } else {
                    Text("-")
                        .foregroundStyle(colors.textTertiary)
                }
            }
            .frame(width: 30, alignment: .trailing)
            .font(.system(size: theme.typography.captionSize).monospacedDigit())

            // Title and artist
            VStack(alignment: .leading, spacing: 2) {
                Text(trackInfo.track.title)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? colors.accent : colors.textPrimary)

                HStack(spacing: 4) {
                    if let artist = trackInfo.artist {
                        Text(artist.name)
                            .foregroundStyle(colors.textSecondary)
                    }
                    if showAlbum, let album = trackInfo.album {
                        if trackInfo.artist != nil {
                            Text("·")
                                .foregroundStyle(colors.textTertiary)
                        }
                        Text(album.title)
                            .foregroundStyle(colors.textTertiary)
                    }
                }
                .font(.system(size: theme.typography.captionSize))
                .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(TimeFormatter.format(trackInfo.track.duration))
                .font(.system(size: theme.typography.captionSize).monospacedDigit())
                .foregroundStyle(colors.textTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: theme.shapes.sidebarItemRadius)
                .fill(isHovered ? colors.surfaceHover : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .draggable(LibraryDragItem.track(trackInfo))
        .onTapGesture(count: 2) {
            onPlay()
        }
        .contextMenu {
            if let onEdit {
                Button("Edit...") {
                    onEdit()
                }
            }

            if let onAddToQueue {
                Button("Add to Queue") {
                    onAddToQueue()
                }
            }

            if let onSyncToggle {
                Button(isInSyncList ? "Remove from Sync List" : "Add to Sync List") {
                    onSyncToggle()
                }
            }

            if let onAddToPlaylist, !playlists.isEmpty {
                Menu("Add to Playlist") {
                    ForEach(playlists) { playlist in
                        Button(playlist.name) {
                            onAddToPlaylist(playlist)
                        }
                    }
                }
            }

            if let onDelete {
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}
