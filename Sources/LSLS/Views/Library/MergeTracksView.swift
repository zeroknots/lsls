import SwiftUI
import GRDB

enum TrackMergeMode: String, CaseIterable {
    case album = "Merge to Album"
    case artist = "Merge Artist"
}

struct MergeTracksView: View {
    let selectedTracks: [TrackInfo]
    var onSave: () -> Void

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var mergeMode: TrackMergeMode = .album
    @State private var artistName: String = ""
    @State private var albumTitle: String = ""
    @State private var allArtists: [Artist] = []
    @State private var artistFilter: String = ""

    private let db = DatabaseManager.shared

    private var filteredArtists: [Artist] {
        let query = mergeMode == .artist ? artistFilter : artistName
        if query.isEmpty { return allArtists }
        return allArtists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var canMerge: Bool {
        let name = artistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return false }
        if mergeMode == .album {
            return !albumTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Tracks")
                .font(.system(size: theme.typography.titleSize, weight: .bold))
                .foregroundStyle(colors.textPrimary)

            Picker("", selection: $mergeMode) {
                ForEach(TrackMergeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Selected tracks list
            VStack(alignment: .leading, spacing: 4) {
                Text("\(selectedTracks.count) songs selected")
                    .font(.system(size: theme.typography.captionSize, weight: .medium))
                    .foregroundStyle(colors.textSecondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(selectedTracks) { trackInfo in
                            HStack(spacing: 6) {
                                Text(trackInfo.track.title)
                                    .foregroundStyle(colors.textPrimary)
                                if let artist = trackInfo.artist {
                                    Text("— \(artist.name)")
                                        .foregroundStyle(colors.textTertiary)
                                }
                            }
                            .font(.system(size: theme.typography.captionSize))
                            .lineLimit(1)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }

            Divider()

            if mergeMode == .album {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Album Title")
                        .font(.system(size: theme.typography.captionSize, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                    TextField("Album title", text: $albumTitle)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Artist picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Artist")
                    .font(.system(size: theme.typography.captionSize, weight: .medium))
                    .foregroundStyle(colors.textSecondary)

                if mergeMode == .artist {
                    TextField("Filter artists...", text: $artistFilter)
                        .textFieldStyle(.roundedBorder)
                } else {
                    TextField("Artist name", text: $artistName)
                        .textFieldStyle(.roundedBorder)
                }

                List(filteredArtists) { artist in
                    Text(artist.name)
                        .foregroundStyle(
                            artistName == artist.name
                                ? colors.accent
                                : colors.textPrimary
                        )
                        .font(.system(size: theme.typography.bodySize))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            artistName = artist.name
                            artistFilter = artist.name
                        }
                }
                .listStyle(.bordered)
                .frame(height: 120)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Merge") {
                    performMerge()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canMerge)
            }
        }
        .padding(24)
        .frame(width: 450, height: 520)
        .background(colors.background)
        .task {
            loadArtists()
            prefillDefaults()
        }
    }

    private func loadArtists() {
        do {
            allArtists = try db.dbPool.read { db in
                try LibraryQueries.allArtists(in: db)
            }
        } catch {
            print("Failed to load artists: \(error)")
        }
    }

    private func prefillDefaults() {
        // Most common artist among selected tracks
        var artistCounts: [String: Int] = [:]
        for trackInfo in selectedTracks {
            if let name = trackInfo.artist?.name {
                artistCounts[name, default: 0] += 1
            }
        }
        let mostCommonArtist = artistCounts.max(by: { $0.value < $1.value })?.key ?? ""
        artistName = mostCommonArtist
        artistFilter = mostCommonArtist

        // Most common album title among selected tracks
        var albumCounts: [String: Int] = [:]
        for trackInfo in selectedTracks {
            if let title = trackInfo.album?.title {
                albumCounts[title, default: 0] += 1
            }
        }
        albumTitle = albumCounts.max(by: { $0.value < $1.value })?.key ?? ""
    }

    private func performMerge() {
        let trackIds = selectedTracks.compactMap { $0.track.id }
        guard !trackIds.isEmpty else { return }

        let trimmedArtist = artistName.trimmingCharacters(in: .whitespaces)
        guard !trimmedArtist.isEmpty else { return }

        do {
            try db.dbPool.write { dbConn in
                switch mergeMode {
                case .album:
                    let trimmedTitle = albumTitle.trimmingCharacters(in: .whitespaces)
                    guard !trimmedTitle.isEmpty else { return }
                    try LibraryQueries.mergeTracksToAlbum(
                        trackIds: trackIds,
                        albumTitle: trimmedTitle,
                        artistName: trimmedArtist,
                        in: dbConn
                    )
                case .artist:
                    try LibraryQueries.mergeTracksToArtist(
                        trackIds: trackIds,
                        artistName: trimmedArtist,
                        in: dbConn
                    )
                }
            }
            onSave()
            dismiss()
        } catch {
            print("Failed to merge tracks: \(error)")
        }
    }
}
