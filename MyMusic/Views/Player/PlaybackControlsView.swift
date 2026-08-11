import SwiftUI

struct PlaybackControlsView: View {
    let isPlaying: Bool
    let isLoading: Bool
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onShuffle: () -> Void
    let onRepeat: () -> Void

    var body: some View {
        VStack(spacing: 18) {
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
            .font(.title)

            HStack {
                Button("Shuffle", systemImage: "shuffle", action: onShuffle)
                    .foregroundStyle(isShuffleEnabled ? Color.accentColor : Color.secondary)
                    .accessibilityValue(isShuffleEnabled ? "On" : "Off")
                Spacer()
                Button(repeatLabel, systemImage: repeatSymbol, action: onRepeat)
                    .foregroundStyle(repeatMode == .off ? Color.secondary : Color.accentColor)
                    .accessibilityValue(repeatLabel)
            }
            .font(.title3)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
    }

    private var repeatSymbol: String {
        repeatMode == .one ? "repeat.1" : "repeat"
    }

    private var repeatLabel: String {
        switch repeatMode {
        case .off: "Repeat Off"
        case .all: "Repeat All"
        case .one: "Repeat One"
        }
    }
}
