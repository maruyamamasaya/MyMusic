import SwiftUI

struct MiniPlayerView: View {
    let onOpen: () -> Void

    var body: some View {
        SceneryBGMOverlay(onReturn: onOpen, isCollapsed: .constant(false), isMiniPlayer: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
    }
}
