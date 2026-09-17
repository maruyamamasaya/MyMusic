import SwiftUI

/// Minimal playback controls for the art presentation.
struct VisualWorldController: View {
    @Environment(PlayerStore.self) private var player
    @Environment(TrackPreferenceStore.self) private var preferences

    private var track: Track? { player.currentTrack }
    private var canRate: Bool { track?.isEligibleForRegularPlayback == true }
    private var isFavorite: Bool {
        guard let track else { return false }
        return preferences.isFavorite(trackID: track.id)
    }

    var body: some View {
        HStack(spacing: 3) {
            AlbumArtworkView(artworkIdentifier: track?.artworkIdentifier)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            control("前の曲", symbol: "backward.end.fill",
                    enabled: player.hasPrevious && !player.isLoading, action: player.previous)
            control(player.isPlaying ? "一時停止" : "再生",
                    symbol: player.isPlaying ? "pause.fill" : "play.fill",
                    enabled: track != nil && !player.isLoading, action: player.togglePlayPause)
            control("次の曲", symbol: "forward.end.fill",
                    enabled: player.hasNext && !player.isLoading, action: player.next)
            control(isFavorite ? "いいねを取り消す" : "いいね",
                    symbol: isFavorite ? "heart.fill" : "heart",
                    enabled: canRate, action: toggleFavorite)
                .foregroundStyle(isFavorite ? Color.pink : Color.white)
            control("グッド", symbol: preference > 0 ? "hand.thumbsup.fill" : "hand.thumbsup",
                    enabled: canRate, action: increasePreference)
                .accessibilityValue(preference > 0 ? "\(preference)" : "未評価")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
    }

    private var preference: Int {
        guard let track else { return 0 }
        return preferences.playbackPreference(for: track.id)
    }

    private func control(_ title: String, symbol: String, enabled: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        .disabled(!enabled)
    }

    private func toggleFavorite() {
        guard let track, canRate else { return }
        preferences.toggleFavorite(trackID: track.id)
    }

    private func increasePreference() {
        guard let track, canRate else { return }
        preferences.increasePlaybackPreference(for: track.id)
    }
}
