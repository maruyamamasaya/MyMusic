import SwiftUI

/// A backing beneath each heading and its tiles; artwork itself stays undimmed.
private struct HomeSectionBackdrop: ViewModifier {
    var compactFade = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if theme == .simpleDark {
            content
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    backdrop
                        .allowsHitTesting(false)
                }
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if reduceTransparency || contrast == .increased {
            Rectangle().fill(.black)
        } else {
            // Match the player backing: preserve readability and soften only the edges.
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black.opacity(0.60)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: compactFade ? 6 : 16)
                Rectangle().fill(.black.opacity(0.60))
                LinearGradient(colors: [.black.opacity(0.60), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: compactFade ? 6 : 16)
            }
            .padding(.vertical, compactFade ? 0 : -16)
        }
    }
}

extension View {
    func homeSectionBackdrop(compactFade: Bool = false) -> some View {
        modifier(HomeSectionBackdrop(compactFade: compactFade))
    }
}
