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

                    Button("Show Queue", systemImage: "list.bullet") {
                        isQueuePresented = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close Now Playing")
                }
            }
            .sheet(isPresented: $isQueuePresented) {
                QueueView()
            }
        }
    }
}
