import SwiftUI

enum ThemeFontStyle {
    case title, headline, body, caption, smallCaption, monoDigit
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackgroundModifier())
    }

    func themedCard() -> some View {
        modifier(ThemedCardModifier())
    }

    func themedFont(_ style: ThemeFontStyle) -> some View {
        modifier(ThemedFontModifier(style: style))
    }
}

private struct ThemedBackgroundModifier: ViewModifier {
    @Environment(\.themeColors) private var colors

    func body(content: Content) -> some View {
        content.background(colors.background)
    }
}

private struct ThemedCardModifier: ViewModifier {
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.shapes.cardRadius))
            .shadow(
                color: .black.opacity(theme.effects.cardShadowOpacity),
                radius: theme.effects.cardShadowRadius
            )
    }
}

private struct ThemedFontModifier: ViewModifier {
    let style: ThemeFontStyle
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.font(resolvedFont)
    }

    private var resolvedFont: Font {
        let typo = theme.typography
        let weight = fontWeight(from: style == .title ? typo.titleWeight : typo.bodyWeight)

        switch style {
        case .title:
            return .system(size: typo.titleSize, weight: weight)
        case .headline:
            return .system(size: typo.headlineSize, weight: .semibold)
        case .body:
            return .system(size: typo.bodySize, weight: weight)
        case .caption:
            return .system(size: typo.captionSize, weight: .regular)
        case .smallCaption:
            return .system(size: typo.smallCaptionSize, weight: .regular)
        case .monoDigit:
            return .system(size: typo.captionSize, weight: .regular).monospacedDigit()
        }
    }

    private func fontWeight(from string: String) -> Font.Weight {
        switch string.lowercased() {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "light": return .light
        default: return .regular
        }
    }
}
