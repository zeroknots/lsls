import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 14, weight: .medium)
    var speed: Double = 30

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var shouldScroll: Bool { textWidth > containerWidth + 1 }
    private let gap: CGFloat = 40

    var body: some View {
        GeometryReader { geo in
            if shouldScroll {
                TimelineView(.animation) { context in
                    let totalDistance = textWidth + gap
                    let duration = totalDistance / speed
                    let elapsed = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
                    let offset = -elapsed * speed

                    HStack(spacing: gap) {
                        Text(text).font(font).fixedSize()
                        Text(text).font(font).fixedSize()
                    }
                    .offset(x: offset)
                }
            } else {
                Text(text)
                    .font(font)
                    .lineLimit(1)
            }
        }
        .frame(height: textHeight)
        .clipped()
        .overlay(
            Text(text).font(font).fixedSize().hidden()
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { textWidth = geo.size.width }
                        .onChange(of: text) { _, _ in textWidth = geo.size.width }
                })
        )
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, new in containerWidth = new }
        })
    }

    private var textHeight: CGFloat { 20 }
}
