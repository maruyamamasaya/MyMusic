import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let isLoading: Bool
    let onPlayPause: () -> Void

    var body: some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Loading audio")
            } else {
                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                    onPlayPause()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 64))
                .buttonStyle(.plain)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }
            Spacer()
        }
    }
}
