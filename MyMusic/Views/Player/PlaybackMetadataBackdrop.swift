import SwiftUI

/// Keeps playback credits readable without blurring their text or actions.
private struct PlaybackMetadataBackdrop: ViewModifier {
    var verticalPadding: CGFloat = 12
    var horizontalOutset: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(.vertical, verticalPadding)
            .background {
                backdrop
                    .padding(.horizontal, -horizontalOutset)
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var backdrop: some View {
        if reduceTransparency || contrast == .increased {
            Rectangle().fill(.black)
        } else {
            // Keep the full-strength backing behind the content; fade only outside it.
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black.opacity(0.60)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
                Rectangle().fill(.black.opacity(0.60))
                LinearGradient(colors: [.black.opacity(0.60), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
            }
            .padding(.vertical, -16)
        }
    }
}

extension View {
    func playbackMetadataBackdrop(verticalPadding: CGFloat = 12, horizontalOutset: CGFloat = 24) -> some View {
        modifier(PlaybackMetadataBackdrop(verticalPadding: verticalPadding, horizontalOutset: horizontalOutset))
    }
}
