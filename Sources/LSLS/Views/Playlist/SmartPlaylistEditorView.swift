import SwiftUI
import GRDB

struct SmartPlaylistEditorView: View {
    let smartPlaylist: SmartPlaylist?
    var onSave: () -> Void

    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var rules: [EditableRule] = []
    @State private var matchCount: Int = 0

    private let db = DatabaseManager.shared

    private var isEditing: Bool {
        smartPlaylist != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerView
            nameFieldView

            if !isEditing {
                presetsView
            }

            rulesSection
            matchCountView

            Spacer()

            bottomButtonsView
        }
        .padding(24)
        .frame(width: 450, height: 580)
        .background(colors.background)
        .task {
            if let playlist = smartPlaylist {
                name = playlist.name
                loadExistingRules()
            }
        }
    }

    private var headerView: some View {
        Text(isEditing ? "Edit Smart Playlist" : "New Smart Playlist")
            .font(.system(size: theme.typography.titleSize, weight: .bold))
            .foregroundStyle(colors.textPrimary)
    }

    private var nameFieldView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.system(size: theme.typography.captionSize, weight: .medium))
                .foregroundStyle(colors.textSecondary)
            TextField("Smart playlist name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var presetsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Presets")
                .font(.system(size: theme.typography.captionSize, weight: .medium))
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: 8) {
                Button("Most Played") {
                    applyMostPlayedPreset()
                }
                .buttonStyle(.bordered)

                Button("Favorites") {
                    applyFavoritesPreset()
                }
                .buttonStyle(.bordered)

                Button("Recently Played") {
                    applyRecentlyPlayedPreset()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rules")
                .font(.system(size: theme.typography.captionSize, weight: .medium))
                .foregroundStyle(colors.textSecondary)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(rules) { rule in
                        RuleRow(
                            rule: rule,
                            colors: colors,
                            theme: theme,
                            onChange: { updatedRule in
                                if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                                    rules[index] = updatedRule
                                    updateMatchCount()
                                }
                            },
                            onRemove: {
                                rules.removeAll { $0.id == rule.id }
                                updateMatchCount()
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 200)

            Button(action: addRule) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Rule")
                }
                .font(.system(size: theme.typography.bodySize))
            }
            .buttonStyle(.bordered)
        }
    }

    private var matchCountView: some View {
        Text("Matches \(matchCount) songs")
            .font(.system(size: theme.typography.bodySize))
            .foregroundStyle(colors.textSecondary)
    }

    private var bottomButtonsView: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Save") {
                saveSmartPlaylist()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || rules.isEmpty)
        }
    }

    private func addRule() {
        let newRule = EditableRule(
            field: .playCount,
            operator: .greaterThan,
            value: ""
        )
        rules.append(newRule)
    }

    private func loadExistingRules() {
        guard let playlistId = smartPlaylist?.id else { return }

        do {
            let existingRules = try db.dbQueue.read { db in
                try LibraryQueries.rulesForSmartPlaylist(playlistId, in: db)
            }

            rules = existingRules.map { rule in
                EditableRule(
                    field: rule.field,
                    operator: rule.operator,
                    value: rule.value
                )
            }

            updateMatchCount()
        } catch {
            print("Failed to load smart playlist rules: \(error)")
        }
    }

    private func updateMatchCount() {
        guard !rules.isEmpty else {
            matchCount = 0
            return
        }

        let tempRules = rules.enumerated().map { index, editableRule in
            SmartPlaylistRule(
                id: nil,
                smartPlaylistId: 0,
                field: editableRule.field,
                operator: editableRule.operator,
                value: editableRule.value,
                position: index
            )
        }

        do {
            let tracks = try db.dbQueue.read { db in
                try LibraryQueries.smartPlaylistTracks(tempRules, in: db)
            }
            matchCount = tracks.count
        } catch {
            print("Failed to get match count: \(error)")
            matchCount = 0
        }
    }

    private func saveSmartPlaylist() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !rules.isEmpty else { return }

        do {
            try db.dbQueue.write { dbConn in
                var playlist: SmartPlaylist

                if let existing = smartPlaylist, let existingId = existing.id {
                    playlist = SmartPlaylist(
                        id: existingId,
                        name: trimmedName,
                        dateCreated: existing.dateCreated
                    )
                    try playlist.update(dbConn)

                    // Delete old rules
                    try SmartPlaylistRule
                        .filter(SmartPlaylistRule.Columns.smartPlaylistId == existingId)
                        .deleteAll(dbConn)
                } else {
                    playlist = SmartPlaylist(
                        name: trimmedName,
                        dateCreated: Date()
                    )
                    try playlist.insert(dbConn)
                }

                guard let playlistId = playlist.id else { return }

                // Insert new rules
                for (index, editableRule) in rules.enumerated() {
                    var rule = SmartPlaylistRule(
                        id: nil,
                        smartPlaylistId: playlistId,
                        field: editableRule.field,
                        operator: editableRule.operator,
                        value: editableRule.value,
                        position: index
                    )
                    try rule.insert(dbConn)
                }
            }

            onSave()
            dismiss()
        } catch {
            print("Failed to save smart playlist: \(error)")
        }
    }

    private func applyMostPlayedPreset() {
        name = "Most Played"
        rules = [
            EditableRule(
                field: .playCount,
                operator: .greaterThan,
                value: "5"
            )
        ]
        updateMatchCount()
    }

    private func applyFavoritesPreset() {
        name = "Favorites"
        rules = [
            EditableRule(
                field: .isFavorite,
                operator: .isTrue,
                value: ""
            )
        ]
        updateMatchCount()
    }

    private func applyRecentlyPlayedPreset() {
        name = "Recently Played"
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let isoDate = ISO8601DateFormatter().string(from: sevenDaysAgo)

        rules = [
            EditableRule(
                field: .lastPlayedAt,
                operator: .greaterThan,
                value: isoDate
            )
        ]
        updateMatchCount()
    }
}

struct EditableRule: Identifiable {
    let id = UUID()
    var field: SmartPlaylistField
    var `operator`: SmartPlaylistOperator
    var value: String
}

struct RuleRow: View {
    let rule: EditableRule
    let colors: ResolvedThemeColors
    let theme: ThemeDefinition
    let onChange: (EditableRule) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Field picker
            Picker("", selection: Binding(
                get: { rule.field },
                set: { newField in
                    var updated = rule
                    updated.field = newField
                    // Update operator to first available for new field
                    if !newField.availableOperators.contains(updated.operator) {
                        updated.operator = newField.availableOperators.first ?? .equals
                    }
                    onChange(updated)
                }
            )) {
                ForEach(SmartPlaylistField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .frame(width: 120)

            // Operator picker
            Picker("", selection: Binding(
                get: { rule.operator },
                set: { newOperator in
                    var updated = rule
                    updated.operator = newOperator
                    onChange(updated)
                }
            )) {
                ForEach(rule.field.availableOperators, id: \.self) { op in
                    Text(op.displayName).tag(op)
                }
            }
            .frame(width: 120)

            // Value field (hidden for isFavorite)
            if rule.field != .isFavorite {
                TextField("Value", text: Binding(
                    get: { rule.value },
                    set: { newValue in
                        var updated = rule
                        updated.value = newValue
                        onChange(updated)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Remove rule")
        }
    }
}
