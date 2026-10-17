import SwiftUI

/// Scenery-only presentation; preference values and persistence use the existing store.
struct SceneryPreferenceControls: View {
    @Environment(TrackPreferenceStore.self) private var preferences
    let track: Track

    private var level: Int { max(0, preferences.playbackPreference(for: track.id)) }
    private var favorite: Bool { preferences.isFavorite(trackID: track.id) }

    var body: some View {
        HStack(spacing: 0) {
            Button { preferences.toggleFavorite(trackID: track.id) } label: {
                Image(systemName: favorite ? "heart.fill" : "heart")
                    .font(.caption)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel(favorite ? "お気に入りから削除" : "お気に入りに追加")

            Button { preferences.increasePlaybackPreference(for: track.id) } label: {
                HStack(spacing: 2) {
                    Image(systemName: level > 0 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.body)
                    if level > 0 {
                        Text("\(level)")
                            .font(.custom("DotGothic16-Regular", fixedSize: 9))
                            .fixedSize()
                    }
                }
                .frame(minWidth: 40, minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("再生頻度を増やす")
            .accessibilityValue("\(level)、上限15、選曲への効果は10で最大")
        }
        .foregroundStyle(SceneryPlayerAppearance.display)
        .buttonStyle(.plain)
        .disabled(preferences.isImporting)
        .transaction { $0.animation = nil }
    }
}
