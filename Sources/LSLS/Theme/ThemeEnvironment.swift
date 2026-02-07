import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = BuiltInThemes.darkMinimal
}

private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue = ResolvedThemeColors(from: BuiltInThemes.darkMinimal.colors)
}

extension EnvironmentValues {
    var theme: ThemeDefinition {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    var themeColors: ResolvedThemeColors {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}
