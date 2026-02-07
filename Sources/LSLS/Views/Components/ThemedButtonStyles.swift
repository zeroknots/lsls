import SwiftUI

struct AccentFilledButtonStyle: ButtonStyle {
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: theme.typography.bodySize, weight: .semibold))
            .foregroundStyle(colors.background)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(colors.accent)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AccentOutlineButtonStyle: ButtonStyle {
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: theme.typography.bodySize, weight: .semibold))
            .foregroundStyle(colors.accent)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .stroke(colors.accent, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
