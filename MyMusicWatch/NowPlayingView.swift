import SwiftUI

struct NowPlayingView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        let state = sessionManager.playbackState
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 54, height: 54)
            .accessibilityLabel("アートワーク")

            VStack(spacing: 1) {
                Text(state.trackID == nil ? "再生中の曲はありません" : state.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.trackID == nil ? connectionText : state.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 18) {
                controlButton("backward.fill", label: "前の曲", command: .previous)
                controlButton(
                    state.isPlaying ? "pause.fill" : "play.fill",
                    label: state.isPlaying ? "一時停止" : "再生",
                    command: .togglePlayPause
                )
                controlButton("forward.fill", label: "次の曲", command: .next)
            }
            .font(.title3)
            .disabled(!sessionManager.isPhoneReachable || state.trackID == nil)

            if state.duration > 0 {
                ProgressView(value: min(state.currentTime, state.duration), total: state.duration)
                    .accessibilityLabel("再生位置")
            }
        }
        .padding(.horizontal, 8)
    }

    private var connectionText: String {
        sessionManager.errorMessage ?? (sessionManager.isPhoneReachable ? "iPhoneで曲を選んでください" : "iPhone未接続")
    }

    private func controlButton(_ symbol: String, label: String, command: WatchPlaybackCommand) -> some View {
        Button { sessionManager.send(command) } label: {
            Image(systemName: symbol).frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
