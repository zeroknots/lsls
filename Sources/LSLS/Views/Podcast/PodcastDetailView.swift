import SwiftUI

struct PodcastDetailView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(PodcastManager.self) private var podcastManager

    let podcast: Podcast
    var onUnsubscribe: (() -> Void)?

    @State private var isRefreshing: Bool = false
    @State private var errorMessage: String?

    private var episodes: [Episode] {
        podcastManager.episodesForPodcast(podcast.id ?? -1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                podcastHeader

                Divider()
                    .padding(.vertical, 16)

                episodesList
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await refreshFeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)

                Toggle(isOn: syncBinding) {
                    Label("Sync to DAP", systemImage: "arrow.triangle.2.circlepath")
                }
                .toggleStyle(.button)

                Button(role: .destructive) {
                    unsubscribe()
                } label: {
                    Label("Unsubscribe", systemImage: "minus.circle")
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var podcastHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: URL(string: podcast.artworkUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(colors.accentSubtle)
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 12) {
                Text(podcast.title)
                    .font(.system(size: theme.typography.bodySize * 1.5, weight: .bold))
                    .foregroundStyle(colors.textPrimary)

                if let author = podcast.author {
                    Text(author)
                        .font(.system(size: theme.typography.bodySize, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                }

                if let description = podcast.podcastDescription {
                    Text(description)
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textTertiary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    if let lastFetched = podcast.lastFetchedAt {
                        Label(
                            "Updated \(lastFetched.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: "clock"
                        )
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textTertiary)
                    }

                    Label("\(episodes.count) episodes", systemImage: "number")
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textTertiary)

                    let downloadedCount = episodes.filter(\.isDownloaded).count
                    if downloadedCount > 0 {
                        Label("\(downloadedCount) downloaded", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: theme.typography.smallCaptionSize))
                            .foregroundStyle(colors.textTertiary)
                    }
                }
            }

            Spacer()
        }
    }

    private var episodesList: some View {
        VStack(spacing: 0) {
            if episodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(colors.textTertiary)

                    Text("No Episodes")
                        .font(.system(size: theme.typography.bodySize))
                        .foregroundStyle(colors.textSecondary)

                    Text("Refresh to fetch episodes")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ForEach(episodes) { episode in
                    episodeRow(episode)

                    if episode.id != episodes.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .background(colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
    }

    private func episodeRow(_ episode: Episode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            playStatusIndicator(episode)

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.title)
                    .font(.system(size: theme.typography.bodySize, weight: .medium))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Text(episode.pubDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)

                    Text(TimeFormatter.formatLong(episode.duration))
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)

                    if episode.isDownloaded {
                        Label("Downloaded", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: theme.typography.captionSize))
                            .foregroundStyle(colors.accent)
                    }
                }

                if let description = episode.episodeDescription {
                    Text(description)
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    playEpisode(episode)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(colors.accent)
                }
                .buttonStyle(.plain)
                .help("Play")

                if episode.isDownloaded {
                    Button {
                        podcastManager.deleteDownload(episode)
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Download")
                } else if podcastManager.downloadingEpisodeId == episode.id {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                } else {
                    Button {
                        Task {
                            await downloadEpisode(episode)
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Download")
                    .disabled(podcastManager.isDownloading)
                }
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            playEpisode(episode)
        }
        .contextMenu {
            Button {
                playEpisode(episode)
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            if episode.isDownloaded {
                Button {
                    podcastManager.deleteDownload(episode)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            } else {
                Button {
                    Task {
                        await downloadEpisode(episode)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }

            if !episode.isPlayed {
                Button {
                    podcastManager.markPlayed(episode)
                } label: {
                    Label("Mark as Played", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private func playStatusIndicator(_ episode: Episode) -> some View {
        ZStack {
            Circle()
                .strokeBorder(colors.textTertiary, lineWidth: 2)
                .frame(width: 24, height: 24)

            if episode.isPlayed {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(colors.accent)
            } else if episode.playbackPosition > 0 {
                Circle()
                    .fill(colors.accent)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 36)
    }

    private var syncBinding: Binding<Bool> {
        Binding(
            get: {
                if let podcastId = podcast.id {
                    return podcastManager.isPodcastInSyncList(podcastId)
                }
                return false
            },
            set: { newValue in
                guard let podcastId = podcast.id else { return }
                if newValue {
                    podcastManager.addPodcastToSyncList(podcastId)
                } else {
                    podcastManager.removePodcastFromSyncList(podcastId)
                }
            }
        )
    }

    private func refreshFeed() async {
        isRefreshing = true
        errorMessage = nil

        do {
            try await podcastManager.refreshFeed(podcast)
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    private func unsubscribe() {
        podcastManager.unsubscribe(podcast)
        onUnsubscribe?()
    }

    private func playEpisode(_ episode: Episode) {
        podcastManager.playEpisode(episode, podcast: podcast)
    }

    private func downloadEpisode(_ episode: Episode) async {
        errorMessage = nil

        do {
            try await podcastManager.downloadEpisode(episode)
        } catch {
            errorMessage = "Failed to download: \(error.localizedDescription)"
        }
    }
}
