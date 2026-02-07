import SwiftUI

struct QueueSidebarView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

            if let current = playerState.queue.current {
                nowPlayingSection(current)

                Rectangle()
                    .fill(colors.separator)
                    .frame(height: 1)
            }

            upNextSection
        }
        .background(colors.backgroundSecondary)
        .dropDestination(for: LibraryDragItem.self) { items, _ in
            for item in items {
                handleDrop(item)
            }
            return true
        }
    }

    private var header: some View {
        HStack {
            Text("Queue")
                .font(.system(size: theme.typography.headlineSize, weight: .bold))
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text("\(playerState.queue.upNext.count) upcoming")
                .font(.system(size: theme.typography.captionSize))
                .foregroundStyle(colors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func nowPlayingSection(_ track: TrackInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOW PLAYING")
                .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                .foregroundStyle(colors.textTertiary)

            HStack(spacing: 10) {
                if let album = track.album {
                    AlbumArtView(album: album, size: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.track.title)
                        .font(.system(size: theme.typography.bodySize, weight: .medium))
                        .foregroundStyle(colors.accent)
                        .lineLimit(1)
                    if let artist = track.artist {
                        Text(artist.name)
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func handleDrop(_ item: LibraryDragItem) {
        switch item {
        case .track(let trackInfo):
            playerState.addToQueueEnd(trackInfo)
        case .album(let albumInfo):
            if let albumId = albumInfo.album.id {
                playerState.addAlbumToQueue(albumId)
            }
        case .artist(let artist):
            if let artistId = artist.id {
                playerState.addArtistToQueue(artistId)
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let upNext = playerState.queue.upNext

        if upNext.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundStyle(colors.textTertiary)
                Text("Queue is empty")
                    .font(.system(size: theme.typography.captionSize))
                    .foregroundStyle(colors.textTertiary)
                Text("Right-click a song or drag it here")
                    .font(.system(size: theme.typography.smallCaptionSize))
                    .foregroundStyle(colors.textTertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("UP NEXT")
                    .font(.system(size: theme.typography.smallCaptionSize, weight: .semibold))
                    .foregroundStyle(colors.textTertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                List {
                    ForEach(Array(upNext.enumerated()), id: \.element.id) { index, trackInfo in
                        QueueTrackRow(trackInfo: trackInfo)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button("Remove from Queue", role: .destructive) {
                                    playerState.removeFromQueue(at: index)
                                }
                            }
                    }
                    .onMove { source, destination in
                        let offset = playerState.queue.currentIndex + 1
                        let absoluteSource = IndexSet(source.map { $0 + offset })
                        let absoluteDestination = destination + offset
                        playerState.moveInQueue(
                            fromOffsets: absoluteSource,
                            toOffset: absoluteDestination
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted().reversed() {
                            playerState.removeFromQueue(at: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
