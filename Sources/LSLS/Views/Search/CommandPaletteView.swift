import SwiftUI
import GRDB

struct CommandPaletteView: View {
    @Environment(PlayerState.self) private var playerState
    @Environment(NavigationRequest.self) private var navigationRequest
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Binding var isPresented: Bool

    var onNavigateToArtist: (Artist) -> Void
    var onNavigateToAlbum: (Album) -> Void
    var onNavigateToTrack: (TrackInfo) -> Void
    var onPlayTrack: (TrackInfo) -> Void

    @State private var searchText = ""
    @State private var results: [CommandPaletteResult] = []
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(colors.textTertiary)
                    .font(.system(size: 16))

                TextField("Search songs, artists, albums...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(colors.textPrimary)
                    .focused($isSearchFocused)
                    .onSubmit { handleSubmit() }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Text("esc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(colors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colors.surfaceHover)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle()
                .fill(colors.separator)
                .frame(height: 1)

            // Results
            if results.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(colors.textTertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if results.isEmpty {
                VStack(spacing: 8) {
                    Text("Type to search your library")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                resultRow(result, isSelected: index == selectedIndex)
                                    .id(result.id)
                                    .onTapGesture {
                                        selectedIndex = index
                                        handleSubmit()
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < results.count {
                            withAnimation {
                                proxy.scrollTo(results[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colors.separator.opacity(0.5), lineWidth: 1)
        )
        .frame(width: 520)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(newValue)
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    @ViewBuilder
    private func resultRow(_ result: CommandPaletteResult, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.iconName)
                .foregroundStyle(isSelected ? colors.accent : colors.textSecondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: theme.typography.bodySize))
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(.system(size: theme.typography.captionSize))
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colors.surfaceHover)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: theme.shapes.sidebarItemRadius)
                .fill(isSelected ? colors.accent.opacity(0.12) : .clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        do {
            results = try db.dbPool.read { db in
                try LibraryQueries.commandPaletteSearch(query, in: db)
            }
        } catch {
            print("Command palette search failed: \(error)")
            results = []
        }
    }

    private func handleSubmit() {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return }
        let result = results[selectedIndex]

        switch result.kind {
        case .artist(let artist):
            isPresented = false
            onNavigateToArtist(artist)

        case .album(let albumInfo):
            isPresented = false
            onNavigateToAlbum(albumInfo.album)

        case .track(let trackInfo):
            isPresented = false
            onNavigateToTrack(trackInfo)
            onPlayTrack(trackInfo)
        }
    }
}
