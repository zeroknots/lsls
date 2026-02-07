import Foundation

enum BuiltInThemes {
    static let darkMinimal = ThemeDefinition()

    static let lightClean = ThemeDefinition(
        meta: ThemeMeta(name: "Light Clean", version: 1, colorSchemeHint: "light"),
        colors: ThemeColors(
            background: ThemeColor(hex: "#F5F5F7"),
            backgroundSecondary: ThemeColor(hex: "#EBEBEE"),
            backgroundTertiary: ThemeColor(hex: "#FFFFFF"),
            surface: ThemeColor(hex: "#FFFFFF"),
            surfaceHover: ThemeColor(hex: "#E8E8EC"),
            textPrimary: ThemeColor(hex: "#1D1D1F"),
            textSecondary: ThemeColor(hex: "#6E6E73"),
            textTertiary: ThemeColor(hex: "#AEAEB2"),
            accent: ThemeColor(hex: "#007AFF"),
            accentSubtle: ThemeColor(hex: "#007AFF", opacity: 0.12),
            separator: ThemeColor(hex: "#D1D1D6"),
            nowPlayingHighlight: ThemeColor(hex: "#007AFF"),
            placeholderGradientStart: ThemeColor(hex: "#E5E5EA"),
            placeholderGradientEnd: ThemeColor(hex: "#F2F2F7")
        ),
        typography: ThemeTypography(),
        spacing: ThemeSpacing(),
        shapes: ThemeShapes(),
        effects: ThemeEffects(
            albumArtShadowRadius: 6,
            albumArtShadowOpacity: 0.12,
            cardShadowRadius: 3,
            cardShadowOpacity: 0.08,
            useVibrancy: true
        )
    )

    static let nord = ThemeDefinition(
        meta: ThemeMeta(name: "Nord", version: 1, colorSchemeHint: "dark"),
        colors: ThemeColors(
            background: ThemeColor(hex: "#2E3440"),
            backgroundSecondary: ThemeColor(hex: "#3B4252"),
            backgroundTertiary: ThemeColor(hex: "#434C5E"),
            surface: ThemeColor(hex: "#3B4252"),
            surfaceHover: ThemeColor(hex: "#434C5E"),
            textPrimary: ThemeColor(hex: "#ECEFF4"),
            textSecondary: ThemeColor(hex: "#D8DEE9"),
            textTertiary: ThemeColor(hex: "#7B88A1"),
            accent: ThemeColor(hex: "#88C0D0"),
            accentSubtle: ThemeColor(hex: "#88C0D0", opacity: 0.15),
            separator: ThemeColor(hex: "#4C566A"),
            nowPlayingHighlight: ThemeColor(hex: "#88C0D0"),
            placeholderGradientStart: ThemeColor(hex: "#3B4252"),
            placeholderGradientEnd: ThemeColor(hex: "#2E3440")
        ),
        typography: ThemeTypography(),
        spacing: ThemeSpacing(),
        shapes: ThemeShapes(albumArtRadius: 8, cardRadius: 10),
        effects: ThemeEffects(useVibrancy: true)
    )

    static let all: [ThemeDefinition] = [darkMinimal, lightClean, nord]
}
