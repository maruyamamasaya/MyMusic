import SwiftUI

/// Keeps playback and each list's existing display controls on one shared row.
struct LibraryPlaybackBar<Controls: View>: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var availableWidth: CGFloat = 0
    let tracks: [Track]
    var isPreparing = false
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                Button(action: playRandomly) {
                    Label("ランダム再生", systemImage: "shuffle")
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(isPreparing || !tracks.contains(where: \.isEligibleForRegularRandomPlayback))

                Spacer(minLength: 16)
                controls()
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .font(.body)
            .frame(minWidth: max(0, availableWidth - 40), minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 20)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .scrollIndicators(.hidden)
        .background(.bar)
    }

    private func playRandomly() {
        var seen = Set<Track.ID>()
        let candidates = tracks.filter {
            $0.isEligibleForRegularRandomPlayback && seen.insert($0.id).inserted
        }
        guard let index = candidates.indices.randomElement() else { return }
        playerStore.setShuffleEnabled(true)
        playerStore.playQueue(
            candidates,
            startingAt: index,
            startContext: PlaybackStartContext(kind: .manual, source: .shuffle)
        )
    }
}
