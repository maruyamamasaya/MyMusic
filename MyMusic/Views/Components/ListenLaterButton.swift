import SwiftUI

struct ListenLaterButton: View {
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(ListenLaterStore.self) private var listenLaterStore

    let track: Track
    var font: Font = .body
    var width: CGFloat = 32

    private var isAdded: Bool { listenLaterStore.contains(track.id) }

    var body: some View {
        Button {
            listenLaterStore.toggle(
                trackID: track.id,
                currentPlayCount: playbackHistoryStore.playCount(for: track.id)
            )
        } label: {
            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                .font(font)
                .foregroundStyle(isAdded ? Color.green : Color.secondary)
                .frame(width: width, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAdded ? "あとで聴くから削除" : "あとで聴くに追加")
    }
}
