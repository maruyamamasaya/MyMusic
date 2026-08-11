import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var isQueuePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    AlbumArtworkView(
                        artworkIdentifier: playerStore.currentTrack?.artworkIdentifier,
                        displayMode: .fitWithBlurredBackground
                    )
                        .containerRelativeFrame(.horizontal) { availableWidth, _ in
                            min(availableWidth * 0.82, 360)
                        }
                        .accessibilityLabel("Artwork for \(playerStore.currentTrack?.title ?? "current track")")

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(playerStore.currentTrack?.title ?? "Not Playing")
                                .font(.title2.bold())
                                .lineLimit(2)
                            Text(playerStore.currentTrack?.artistName ?? "")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let track = playerStore.currentTrack {
                                Text("再生回数 \(playbackHistoryStore.playCount(for: track.id))回")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if let track = playerStore.currentTrack {
                            Button {
                                playbackHistoryStore.toggleFavorite(trackID: track.id)
                            } label: {
                                Image(systemName: playbackHistoryStore.isFavorite(trackID: track.id) ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                            }
                            .accessibilityLabel(playbackHistoryStore.isFavorite(trackID: track.id) ? "Remove from Favorites" : "Add to Favorites")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ProgressBarView(
                        currentTime: playerStore.currentTime,
                        duration: playerStore.duration,
                        onSeek: playerStore.seek
                    )

                    if playerStore.currentTrack != nil {
                        AudioInformationView(information: playerStore.audioInformation)
                    }

                    PlaybackControlsView(
                        isPlaying: playerStore.isPlaying,
                        isLoading: playerStore.isLoading,
                        isShuffleEnabled: playerStore.isShuffleEnabled,
                        repeatMode: playerStore.repeatMode,
                        canGoPrevious: playerStore.hasPrevious,
                        canGoNext: playerStore.hasNext,
                        onPrevious: playerStore.previous,
                        onPlayPause: playerStore.togglePlayPause,
                        onNext: playerStore.next,
                        onShuffle: playerStore.toggleShuffle,
                        onRepeat: playerStore.cycleRepeatMode
                    )

                    Button("再生キューを表示", systemImage: "list.bullet") {
                        isQueuePresented = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("再生中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .accessibilityLabel("再生画面を閉じる")
                }
            }
            .sheet(isPresented: $isQueuePresented) {
                QueueView()
            }
        }
    }
}

private struct AudioInformationView: View {
    let information: AudioInformation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("オーディオ情報")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
                row("コーデック", information.codec)
                row("サンプルレート", rate(information.sampleRate))
                row("ビット深度", information.bitDepth.map { "\($0) bit" } ?? "Unknown")
                row("ビットレート", information.bitRate.map { "\($0 / 1_000) kbps" } ?? "Unknown")
                row("チャンネル", information.channels.map(String.init) ?? "Unknown")
                row("出力先", information.outputName)
                row("出力サンプルレート", rate(information.outputSampleRate))
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func rate(_ value: Double?) -> String {
        guard let value else { return "Unknown" }
        return String(format: "%.1f kHz", value / 1_000)
    }
}
