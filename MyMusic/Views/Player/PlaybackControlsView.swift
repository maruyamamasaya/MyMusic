import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    var body: some View {
        HStack { Button("Shuffle", systemImage: "shuffle") {}; Spacer(); Button("Previous", systemImage: "backward.fill") {}; Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill") {}.font(.largeTitle); Button("Next", systemImage: "forward.fill") {}; Spacer(); Button("Repeat", systemImage: "repeat") {} }.labelStyle(.iconOnly).buttonStyle(.plain)
    }
}
