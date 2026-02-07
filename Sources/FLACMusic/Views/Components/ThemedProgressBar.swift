import SwiftUI

struct ThemedProgressBar: View {
    let progress: Double
    var height: CGFloat = 4
    var showKnob: Bool = true
    var onSeek: ((Double) -> Void)?

    @Environment(\.themeColors) private var colors
    @State private var isDragging = false
    @State private var dragPosition: Double = 0
    @State private var isHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(colors.separator)
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(colors.accent)
                    .frame(width: fillWidth(in: geometry.size.width), height: height)

                // Knob
                if showKnob && (isHovered || isDragging) {
                    Circle()
                        .fill(colors.accent)
                        .frame(width: height * 3, height: height * 3)
                        .shadow(color: colors.accent.opacity(0.3), radius: 4)
                        .offset(x: fillWidth(in: geometry.size.width) - (height * 1.5))
                }
            }
            .frame(height: height)
            .contentShape(Rectangle().inset(by: -10))
            .onHover { isHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragPosition = max(0, min(1, value.location.x / geometry.size.width))
                    }
                    .onEnded { _ in
                        onSeek?(dragPosition)
                        isDragging = false
                    }
            )
        }
        .frame(height: height)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let fraction = isDragging ? dragPosition : max(0, min(1, progress))
        return totalWidth * CGFloat(fraction)
    }
}
