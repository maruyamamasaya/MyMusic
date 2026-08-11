import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss
    @State private var isQueuePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    AlbumArtworkView(artworkIdentifier: playerStore.currentTrack?.artworkIdentifier)
                        .containerRelativeFrame(.horizontal) { availableWidth, _ in
                            min(availableWidth * 0.82, 360)
                        }
                        .accessibilityLabel("Artwork for \(playerStore.currentTrack?.title ?? "current track")")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(playerStore.currentTrack?.title ?? "Not Playing")
                            .font(.title2.bold())
                            .lineLimit(2)
                        Text(playerStore.currentTrack?.artistName ?? "")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                        canGoPrevious: playerStore.hasPrevious,
                        canGoNext: playerStore.hasNext,
                        onPrevious: playerStore.previous,
                        onPlayPause: playerStore.togglePlayPause,
                        onNext: playerStore.next
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
