import SwiftUI

/// Shared generated artwork for the scenery-mode entry points.
struct SceneryModeIcon: View {
    var size: CGFloat = 36

    var body: some View {
        Image("SceneryModeIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
