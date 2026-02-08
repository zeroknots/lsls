import SwiftUI
import GRDB

enum PlaylistPaletteItem: Identifiable, Equatable, Hashable {
    case playlist(Playlist)
    case smartPlaylist(SmartPlaylist)

    var id: String {
        switch self {
        case .playlist(let p): "playlist-\(p.id ?? 0)"
        case .smartPlaylist(let sp): "smart-\(sp.id ?? 0)"
        }
    }

    var name: String {
        switch self {
        case .playlist(let p): p.name
        case .smartPlaylist(let sp): sp.name
        }
    }

    var iconName: String {
        switch self {
        case .playlist: "music.note.list"
        case .smartPlaylist: "gear.badge"
        }
    }
}

struct PlaylistPaletteView: View {
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Binding var isPresented: Bool

    var onSelect: (PlaylistPaletteItem) -> Void

    @State private var searchText = ""
    @State private var allPlaylists: [PlaylistPaletteItem] = []
    @State private var filtered: [PlaylistPaletteItem] = []
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(colors.textTertiary)
                    .font(.system(size: 16))

                TextField("Search playlists...", text: $searchText)
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

            if filtered.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(colors.textTertiary)
                    Text("No playlists matching \"\(searchText)\"")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else if filtered.isEmpty {
                VStack(spacing: 8) {
                    Text("No playlists yet")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                itemRow(item, isSelected: index == selectedIndex)
                                    .id(item.id)
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
                        if newIndex >= 0 && newIndex < filtered.count {
                            withAnimation {
                                proxy.scrollTo(filtered[newIndex].id, anchor: .center)
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
            loadPlaylists()
        }
        .onChange(of: searchText) { _, newValue in
            filterPlaylists(newValue)
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filtered.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PlaylistPaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .foregroundStyle(isSelected ? colors.accent : colors.textSecondary)
                .frame(width: 24, height: 24)

            Text(item.name)
                .font(.system(size: theme.typography.bodySize))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

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

    private func loadPlaylists() {
        do {
            let playlists = try db.dbPool.read { db in
                try LibraryQueries.allPlaylists(in: db)
            }
            let smartPlaylists = try db.dbPool.read { db in
                try LibraryQueries.allSmartPlaylists(in: db)
            }
            allPlaylists = playlists.map { .playlist($0) } + smartPlaylists.map { .smartPlaylist($0) }
            filtered = allPlaylists
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    private func filterPlaylists(_ query: String) {
        guard !query.isEmpty else {
            filtered = allPlaylists
            return
        }
        let tokens = query.lowercased().split(separator: " ").map(String.init)
        filtered = allPlaylists.filter { item in
            let name = item.name.lowercased()
            return tokens.allSatisfy { name.contains($0) }
        }
    }

    private func handleSubmit() {
        guard selectedIndex >= 0 && selectedIndex < filtered.count else { return }
        isPresented = false
        onSelect(filtered[selectedIndex])
    }
}
