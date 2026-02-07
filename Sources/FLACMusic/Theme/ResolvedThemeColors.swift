import SwiftUI

struct ResolvedThemeColors: Equatable, Sendable {
    let background: Color
    let backgroundSecondary: Color
    let backgroundTertiary: Color
    let surface: Color
    let surfaceHover: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    let accent: Color
    let accentSubtle: Color

    let separator: Color
    let nowPlayingHighlight: Color

    let placeholderGradientStart: Color
    let placeholderGradientEnd: Color

    init(from colors: ThemeColors) {
        self.background = colors.background.color
        self.backgroundSecondary = colors.backgroundSecondary.color
        self.backgroundTertiary = colors.backgroundTertiary.color
        self.surface = colors.surface.color
        self.surfaceHover = colors.surfaceHover.color
        self.textPrimary = colors.textPrimary.color
        self.textSecondary = colors.textSecondary.color
        self.textTertiary = colors.textTertiary.color
        self.accent = colors.accent.color
        self.accentSubtle = colors.accentSubtle.color
        self.separator = colors.separator.color
        self.nowPlayingHighlight = colors.nowPlayingHighlight.color
        self.placeholderGradientStart = colors.placeholderGradientStart.color
        self.placeholderGradientEnd = colors.placeholderGradientEnd.color
    }
}
