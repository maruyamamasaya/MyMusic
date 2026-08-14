import SwiftUI

struct PlayableTrackRowView: View {
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    let track: Track
    var showsArtwork = true
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPlay) {
                TrackRowView(track: track, showsArtwork: showsArtwork)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                playbackHistoryStore.toggleFavorite(trackID: track.id)
            } label: {
                Image(systemName: playbackHistoryStore.isFavorite(trackID: track.id) ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playbackHistoryStore.isFavorite(trackID: track.id) ? "お気に入りから削除" : "お気に入りに追加")
        }
    }
}
