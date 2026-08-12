import SwiftUI

struct SingleTrackControlsView: View {
    @Environment(PlayerStore.self) private var playerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerStore.currentTrack?.title ?? "未再生")
                        .font(.headline)
                        .lineLimit(1)
                    Text(playerStore.currentTrack?.artistName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if playerStore.isLoading {
                    ProgressView()
                } else {
                    Button(playerStore.isPlaying ? "一時停止" : "再生", systemImage: playerStore.isPlaying ? "pause.fill" : "play.fill") {
                        playerStore.togglePlayPause()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                }
            }

            ProgressBarView(
                currentTime: playerStore.currentTime,
                duration: playerStore.duration,
                onSeek: playerStore.seek
            )
        }
    }
}
