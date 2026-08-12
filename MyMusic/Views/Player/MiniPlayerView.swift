import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerStore.self) private var playerStore
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        AlbumArtworkView(artworkIdentifier: playerStore.currentTrack?.artworkIdentifier)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playerStore.currentTrack?.title ?? "未再生")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(playerStore.currentTrack?.artistName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if playerStore.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 44, height: 44)
                } else {
                    Button(playerStore.isPlaying ? "一時停止" : "再生", systemImage: playerStore.isPlaying ? "pause.fill" : "play.fill") {
                        playerStore.togglePlayPause()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .scaleEffect(x: 1, y: 0.6, anchor: .center)
                .accessibilityLabel("再生位置")
                .accessibilityValue("\(Int(progress * 100)) percent")
        }
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var progress: Double {
        guard playerStore.duration > 0 else { return 0 }
        return min(max(playerStore.currentTime / playerStore.duration, 0), 1)
    }
}
