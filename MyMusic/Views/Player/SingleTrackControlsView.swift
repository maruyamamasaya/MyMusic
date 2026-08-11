import SwiftUI

struct SingleTrackControlsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var seekValue: TimeInterval = 0
    @State private var isSeeking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerStore.currentTrack?.title ?? "Not Playing")
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
                    Button(playerStore.isPlaying ? "Pause" : "Play", systemImage: playerStore.isPlaying ? "pause.fill" : "play.fill") {
                        playerStore.togglePlayPause()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                }
            }

            Slider(
                value: $seekValue,
                in: 0...max(playerStore.duration, 1),
                onEditingChanged: { editing in
                    isSeeking = editing
                    if !editing { playerStore.seek(to: seekValue) }
                }
            )
            .disabled(playerStore.duration <= 0)

            HStack {
                Text(TimeFormatter.string(from: isSeeking ? seekValue : playerStore.currentTime))
                Spacer()
                Text(TimeFormatter.string(from: playerStore.duration))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .onAppear { seekValue = playerStore.currentTime }
        .onChange(of: playerStore.currentTime) { _, newValue in
            if !isSeeking { seekValue = newValue }
        }
        .onChange(of: playerStore.currentTrack?.id) { _, _ in
            seekValue = 0
        }
    }
}
