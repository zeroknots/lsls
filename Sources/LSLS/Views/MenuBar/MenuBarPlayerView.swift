import AppKit
import SwiftUI

private struct MenuBarAlbumArtView: View {
    let album: Album?
    @State private var image: NSImage?

    var body: some View {
        let displayImage = image ?? album.flatMap({ ArtworkCache.shared.cachedArtwork(for: $0) })

        Group {
            if let displayImage {
                Image(nsImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        .task(id: album?.id) {
            guard let album, image == nil else { return }
            image = await ArtworkCache.shared.loadArtwork(for: album)
        }
    }
}

struct MenuBarPlayerView: View {
    @Environment(PlayerState.self) private var playerState

    @State private var isFavorite = false
    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if let track = playerState.currentTrack {
                nowPlayingContent(track: track)
            } else {
                notPlayingContent
            }

            Divider()
                .padding(.top, 8)

            footerSection
        }
        .frame(width: 300)
        .padding(.vertical, 12)
        .preferredColorScheme(.dark)
        .onChange(of: playerState.currentTrack) {
            loadFavoriteState()
        }
        .task {
            loadFavoriteState()
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private func nowPlayingContent(track: TrackInfo) -> some View {
        // Album art — click to open main window
        Button(action: openMainWindow) {
            albumArt(for: track)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)

        // Track info
        VStack(spacing: 4) {
            MarqueeText(text: track.track.title)
                .foregroundStyle(.primary)

            Text(artistAlbumLine(track))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let format = playerState.currentFormat {
                Text(format.displayString)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)

        // Progress
        progressSection
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

        // Transport controls
        transportControls
            .padding(.bottom, 8)

        // Shuffle / Volume / Repeat
        extraControls
            .padding(.horizontal, 20)
    }

    // MARK: - Album Art

    private func albumArt(for track: TrackInfo) -> some View {
        MenuBarAlbumArtView(album: track.album)
    }

    // MARK: - Progress

    private var progressSection: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            VStack(spacing: 4) {
                menuBarProgressBar

                HStack {
                    Text(TimeFormatter.format(playerState.currentTime))
                    Spacer()
                    Text(TimeFormatter.format(playerState.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var menuBarProgressBar: some View {
        MenuBarProgressBar(
            progress: playerState.duration > 0
                ? playerState.currentTime / playerState.duration : 0
        ) { fraction in
            playerState.seekFraction(fraction)
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 28) {
            Button { playerState.playPrevious() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button { playerState.togglePlayPause() } label: {
                Image(systemName: playerState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button { playerState.playNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Extra Controls

    private var extraControls: some View {
        @Bindable var state = playerState
        return HStack(spacing: 0) {
            Button { playerState.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12))
                    .foregroundStyle(playerState.shuffleEnabled ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: volumeIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Slider(value: $state.volume, in: 0...1)
                    .frame(width: 100)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }

            Spacer()

            Button { playerState.cycleRepeat() } label: {
                Image(systemName: repeatIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(playerState.repeatMode != .off ? .white : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28)
        }
    }

    // MARK: - Not Playing

    private var notPlayingContent: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "music.note")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
            }

            Text("Not Playing")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("Open LSLS") {
                openMainWindow()
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 12))
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    private func artistAlbumLine(_ track: TrackInfo) -> String {
        let artist = track.artist?.name ?? "Unknown Artist"
        if let album = track.album?.title {
            return "\(artist) — \(album)"
        }
        return artist
    }

    private var volumeIcon: String {
        if playerState.volume == 0 {
            return "speaker.slash.fill"
        } else if playerState.volume < 0.33 {
            return "speaker.fill"
        } else if playerState.volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    private var repeatIcon: String {
        switch playerState.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    private func loadFavoriteState() {
        guard let trackId = playerState.currentTrack?.track.id else {
            isFavorite = false
            return
        }
        isFavorite = (try? db.dbPool.read { db in
            try LibraryQueries.isFavorite(trackId: trackId, in: db)
        }) ?? false
    }

    private func toggleFavorite() {
        guard let trackId = playerState.currentTrack?.track.id else { return }
        try? db.dbPool.write { dbConn in
            try LibraryQueries.toggleFavorite(trackId: trackId, in: dbConn)
        }
        isFavorite.toggle()
    }
}

// MARK: - Progress Bar

private struct MenuBarProgressBar: View {
    let progress: Double
    var onSeek: ((Double) -> Void)?

    @State private var isDragging = false
    @State private var dragPosition: Double = 0
    @State private var isHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.white)
                    .frame(width: fillWidth(in: geometry.size.width), height: 4)

                if isHovered || isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .offset(x: fillWidth(in: geometry.size.width) - 5)
                }
            }
            .frame(height: 4)
            .contentShape(Rectangle().inset(by: -8))
            .onHover { isHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragPosition = max(0, min(1, value.location.x / geometry.size.width))
                    }
                    .onEnded { _ in
                        onSeek?(dragPosition)
                        isDragging = false
                    }
            )
        }
        .frame(height: 4)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let fraction = isDragging ? dragPosition : max(0, min(1, progress))
        return totalWidth * CGFloat(fraction)
    }
}
