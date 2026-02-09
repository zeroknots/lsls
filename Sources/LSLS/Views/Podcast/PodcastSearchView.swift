import SwiftUI

struct PodcastSearchView: View {
    @Binding var selectedPodcast: Podcast?

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(PodcastManager.self) private var podcastManager

    @State private var searchQuery: String = ""
    @State private var searchResults: [ApplePodcastSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    if !searchResults.isEmpty {
                        searchResultsSection
                    }

                    if searchQuery.isEmpty {
                        subscribedPodcastsSection
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await refreshAllFeeds()
                    }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
                .disabled(podcastManager.isRefreshing)
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

    private var searchHeader: some View {
        HStack(spacing: 12) {
            TextField("Search podcasts", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task {
                        await performSearch()
                    }
                }

            Button {
                Task {
                    await performSearch()
                }
            } label: {
                Text("Search")
            }
            .disabled(searchQuery.isEmpty || isSearching)
        }
        .padding()
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: theme.typography.bodySize, weight: .semibold))
                .foregroundStyle(colors.textPrimary)

            VStack(spacing: 0) {
                ForEach(searchResults) { result in
                    searchResultRow(result)

                    if result.id != searchResults.last?.id {
                        Divider()
                    }
                }
            }
            .background(colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
        }
    }

    private func searchResultRow(_ result: ApplePodcastSearchResult) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: result.artworkUrl100 ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(colors.accentSubtle)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.collectionName)
                    .font(.system(size: theme.typography.bodySize, weight: .medium))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)

                if let artistName = result.artistName {
                    Text(artistName)
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }

                if let trackCount = result.trackCount {
                    Text("\(trackCount) episodes")
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textTertiary)
                }
            }

            Spacer()

            Button {
                Task {
                    await subscribe(to: result)
                }
            } label: {
                Text("Subscribe")
            }
            .disabled(isAlreadySubscribed(result))
        }
        .padding(12)
    }

    private var subscribedPodcastsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Podcasts")
                .font(.system(size: theme.typography.bodySize, weight: .semibold))
                .foregroundStyle(colors.textPrimary)

            if podcastManager.podcasts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 48))
                        .foregroundStyle(colors.textTertiary)

                    Text("No Subscriptions")
                        .font(.system(size: theme.typography.bodySize))
                        .foregroundStyle(colors.textSecondary)

                    Text("Search for podcasts to subscribe")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(podcastManager.podcasts) { podcast in
                        Button {
                            selectedPodcast = podcast
                        } label: {
                            podcastGridItem(podcast)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Unsubscribe", role: .destructive) {
                                podcastManager.unsubscribe(podcast)
                            }
                        }
                    }
                }
            }
        }
    }

    private func podcastGridItem(_ podcast: Podcast) -> some View {
        let episodes = podcastManager.episodesForPodcast(podcast.id ?? -1)
        let unplayed = episodes.filter { !$0.isPlayed }.count

        return VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: podcast.artworkUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(colors.accentSubtle)
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                if unplayed > 0 {
                    Text("\(unplayed)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colors.accent)
                        .clipShape(Capsule())
                        .offset(x: -6, y: 6)
                }
            }

            VStack(spacing: 2) {
                Text(podcast.title)
                    .font(.system(size: theme.typography.captionSize, weight: .medium))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let author = podcast.author {
                    Text(author)
                        .font(.system(size: theme.typography.smallCaptionSize))
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }

                Text("\(episodes.count) episodes")
                    .font(.system(size: theme.typography.smallCaptionSize))
                    .foregroundStyle(colors.textTertiary)
            }
            .frame(width: 150)
        }
    }

    private func performSearch() async {
        guard !searchQuery.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        do {
            searchResults = try await podcastManager.search(searchQuery)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }

        isSearching = false
    }

    private func subscribe(to result: ApplePodcastSearchResult) async {
        errorMessage = nil

        do {
            try await podcastManager.subscribe(
                feedUrl: result.feedUrl,
                title: result.collectionName,
                author: result.artistName,
                artworkUrl: result.artworkUrl600 ?? result.artworkUrl100
            )
        } catch {
            errorMessage = "Failed to subscribe: \(error.localizedDescription)"
        }
    }

    private func refreshAllFeeds() async {
        errorMessage = nil

        for podcast in podcastManager.podcasts {
            do {
                try await podcastManager.refreshFeed(podcast)
            } catch {
                errorMessage = "Failed to refresh \(podcast.title): \(error.localizedDescription)"
            }
        }
    }

    private func isAlreadySubscribed(_ result: ApplePodcastSearchResult) -> Bool {
        podcastManager.podcasts.contains { $0.feedUrl == result.feedUrl }
    }
}
