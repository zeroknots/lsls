import Foundation

struct ThemeDefinition: Codable, Equatable, Sendable {
    var meta: ThemeMeta = ThemeMeta()
    var colors: ThemeColors = ThemeColors()
    var typography: ThemeTypography = ThemeTypography()
    var spacing: ThemeSpacing = ThemeSpacing()
    var shapes: ThemeShapes = ThemeShapes()
    var effects: ThemeEffects = ThemeEffects()
}

struct ThemeMeta: Codable, Equatable, Sendable {
    var name: String = "Dark Minimal"
    var author: String? = nil
    var version: Int = 1
    var colorSchemeHint: String? = "dark"
}

struct ThemeColors: Codable, Equatable, Sendable {
    var background: ThemeColor = ThemeColor(hex: "#141414")
    var backgroundSecondary: ThemeColor = ThemeColor(hex: "#1C1C1E")
    var backgroundTertiary: ThemeColor = ThemeColor(hex: "#222224")
    var surface: ThemeColor = ThemeColor(hex: "#1C1C1E")
    var surfaceHover: ThemeColor = ThemeColor(hex: "#2C2C2E")

    var textPrimary: ThemeColor = ThemeColor(hex: "#F0F0F0")
    var textSecondary: ThemeColor = ThemeColor(hex: "#98989F")
    var textTertiary: ThemeColor = ThemeColor(hex: "#5A5A5E")

    var accent: ThemeColor = ThemeColor(hex: "#FF6B6B")
    var accentSubtle: ThemeColor = ThemeColor(hex: "#FF6B6B", opacity: 0.15)

    var separator: ThemeColor = ThemeColor(hex: "#38383A")
    var nowPlayingHighlight: ThemeColor = ThemeColor(hex: "#FF6B6B")

    var placeholderGradientStart: ThemeColor = ThemeColor(hex: "#222224")
    var placeholderGradientEnd: ThemeColor = ThemeColor(hex: "#141414")
}

struct ThemeColor: Codable, Equatable, Sendable {
    var hex: String
    var opacity: Double?

    init(hex: String, opacity: Double? = nil) {
        self.hex = hex
        self.opacity = opacity
    }
}

struct ThemeTypography: Codable, Equatable, Sendable {
    var fontFamily: String? = nil
    var titleSize: Double = 22
    var headlineSize: Double = 17
    var bodySize: Double = 14
    var captionSize: Double = 12
    var smallCaptionSize: Double = 10
    var titleWeight: String = "bold"
    var bodyWeight: String = "regular"
    var monospacedDigits: Bool = true
}

struct ThemeSpacing: Codable, Equatable, Sendable {
    var gridItemSize: Double = 180
    var gridSpacing: Double = 20
    var contentPadding: Double = 24
    var sectionSpacing: Double = 24
    var rowHeight: Double = 40
    var nowPlayingBarHeight: Double = 88
}

struct ThemeShapes: Codable, Equatable, Sendable {
    var albumArtRadius: Double = 10
    var cardRadius: Double = 12
    var buttonRadius: Double = 8
    var sidebarItemRadius: Double = 6
}

struct ThemeEffects: Codable, Equatable, Sendable {
    var albumArtShadowRadius: Double = 8
    var albumArtShadowOpacity: Double = 0.3
    var cardShadowRadius: Double = 4
    var cardShadowOpacity: Double = 0.15
    var hoverScale: Double = 1.02
    var useVibrancy: Bool = true
}
