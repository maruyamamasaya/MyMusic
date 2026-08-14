import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let lineHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private let gap: CGFloat = 24
    private let pointsPerSecond: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            Text(singleLineText)
                .font(font)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background {
                    GeometryReader { textProxy in
                        Color.clear
                            .preference(key: MarqueeTextWidthKey.self, value: textProxy.size.width)
                    }
                }
                .offset(x: offset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear { containerWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, width in containerWidth = width }
        }
        .frame(height: lineHeight)
        .clipped()
        .onPreferenceChange(MarqueeTextWidthKey.self) { textWidth = $0 }
        .task(id: animationRequest) {
            await animateIfNeeded()
        }
        .accessibilityLabel(singleLineText)
    }

    private var singleLineText: String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    private var animationRequest: AnimationRequest {
        AnimationRequest(text: singleLineText, textWidth: textWidth, containerWidth: containerWidth, reduceMotion: reduceMotion)
    }

    @MainActor
    private func animateIfNeeded() async {
        resetOffset()
        guard overflow > 0, !reduceMotion else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }

            let distance = overflow + gap
            let duration = max(2, distance / pointsPerSecond)
            withAnimation(.linear(duration: duration)) {
                offset = -distance
            }

            try? await Task.sleep(for: .seconds(duration + 1))
            guard !Task.isCancelled else { return }
            resetOffset()
        }
    }

    @MainActor
    private func resetOffset() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) { offset = 0 }
    }
}

private struct AnimationRequest: Hashable {
    let text: String
    let textWidth: CGFloat
    let containerWidth: CGFloat
    let reduceMotion: Bool
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
