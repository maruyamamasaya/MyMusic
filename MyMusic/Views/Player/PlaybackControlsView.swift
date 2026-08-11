import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let isLoading: Bool
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 36) {
            Button("Previous", systemImage: "backward.end.fill", action: onPrevious)
                .disabled(!canGoPrevious || isLoading)

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Loading audio")
            } else {
                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                    onPlayPause()
                }
                .font(.system(size: 64))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }

            Button("Next", systemImage: "forward.end.fill", action: onNext)
                .disabled(!canGoNext || isLoading)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.title)
    }
}
