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
        HStack {
            Button("シャッフル", systemImage: "shuffle", action: onShuffle)
                .foregroundStyle(isShuffleEnabled ? Color.accentColor : Color.secondary)
                .accessibilityValue(isShuffleEnabled ? "On" : "Off")

            Spacer()

            Button("前の曲", systemImage: "backward.end.fill", action: onPrevious)
                .font(.system(size: 27))
                .disabled(!canGoPrevious || isLoading)

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(width: 62, height: 62)
                    .accessibilityLabel("オーディオを読み込み中")
            } else {
                Button(isPlaying ? "一時停止" : "再生", systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill") {
                    onPlayPause()
                }
                .font(.system(size: 62))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isPlaying ? "一時停止" : "再生")
            }

            Spacer()

            Button("次の曲", systemImage: "forward.end.fill", action: onNext)
                .font(.system(size: 27))
                .disabled(!canGoNext || isLoading)

            Spacer()

            Button(repeatLabel, systemImage: repeatSymbol, action: onRepeat)
                .foregroundStyle(repeatMode == .off ? Color.secondary : Color.accentColor)
                .accessibilityValue(repeatLabel)
        }
        .font(.system(size: 20))
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
