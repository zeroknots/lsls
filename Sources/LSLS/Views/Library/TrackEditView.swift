import SwiftUI
import GRDB

struct TrackEditView: View {
    let trackInfo: TrackInfo
    var onSave: () -> Void

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var selectedArtistId: Int64? = nil
    @State private var newArtistName: String = ""
    @State private var useNewArtist: Bool = false
    @State private var allArtists: [Artist] = []
    @State private var artistFilter: String = ""

    private let db = DatabaseManager.shared

    private var filteredArtists: [Artist] {
        if artistFilter.isEmpty { return allArtists }
        return allArtists.filter {
            $0.name.localizedCaseInsensitiveContains(artistFilter)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Track")
                .font(.system(size: theme.typography.titleSize, weight: .bold))
                .foregroundStyle(colors.textPrimary)

            // Title
            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.system(size: theme.typography.captionSize, weight: .medium))
                    .foregroundStyle(colors.textSecondary)
                TextField("Track title", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
            }

            // Artist
            VStack(alignment: .leading, spacing: 6) {
                Text("Artist")
                    .font(.system(size: theme.typography.captionSize, weight: .medium))
                    .foregroundStyle(colors.textSecondary)

                if useNewArtist {
                    TextField("New artist name", text: $newArtistName)
                        .textFieldStyle(.roundedBorder)
                } else {
                    TextField("Filter artists...", text: $artistFilter)
                        .textFieldStyle(.roundedBorder)

                    List(filteredArtists, selection: $selectedArtistId) { artist in
                        Text(artist.name)
                            .tag(artist.id)
                            .foregroundStyle(
                                selectedArtistId == artist.id
                                    ? colors.accent
                                    : colors.textPrimary
                            )
                    }
                    .listStyle(.bordered)
                    .frame(height: 160)
                }

                Toggle("Create new artist instead", isOn: $useNewArtist)
                    .font(.system(size: theme.typography.captionSize))
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: 440)
        .background(colors.background)
        .task {
            editedTitle = trackInfo.track.title
            selectedArtistId = trackInfo.track.artistId
            loadArtists()
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

    private func saveChanges() {
        guard let trackId = trackInfo.track.id else { return }
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        do {
            try db.dbPool.write { dbConn in
                var artistId = selectedArtistId

                if useNewArtist {
                    let name = newArtistName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        let artist = try LibraryQueries.findOrCreateArtist(name: name, in: dbConn)
                        artistId = artist.id
                    }
                }

                try LibraryQueries.updateTrack(trackId, title: trimmedTitle, artistId: artistId, in: dbConn)
            }
            onSave()
            dismiss()
        } catch {
            print("Failed to save track: \(error)")
        }
    }
}
