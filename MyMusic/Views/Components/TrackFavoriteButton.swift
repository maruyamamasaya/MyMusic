import SwiftUI

struct TrackFavoriteButton: View {
    @Environment(PlaybackHistoryStore.self) private var historyStore

    let track: Track
    var font: Font = .body
    var width: CGFloat = 32

    @State private var effectTrigger = 0
    @State private var showsBurst = false

    private var isFavorite: Bool { historyStore.isFavorite(trackID: track.id) }

    var body: some View {
        Button(action: toggleFavorite) {
            ZStack {
                if showsBurst {
                    Circle()
                        .stroke(Color.pink.opacity(0.75), lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                        .scaleEffect(1.9)
                        .opacity(0)
                }
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(font)
                    .foregroundStyle(isFavorite ? Color.pink : Color.accentColor)
                    .symbolEffect(.bounce, options: .speed(1.6), value: effectTrigger)
                    .scaleEffect(showsBurst ? 1.22 : 1)
                    .frame(width: width, height: 36)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: effectTrigger)
        .accessibilityLabel(isFavorite ? "お気に入りから削除" : "お気に入りに追加")
    }

    private func toggleFavorite() {
        historyStore.toggleFavorite(trackID: track.id)
        effectTrigger += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.48)) { showsBurst = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.38)) { showsBurst = false }
        }
    }
}
