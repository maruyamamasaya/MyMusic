import SwiftUI

struct SelectiveRandomPlayView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var candidateTrackIDs: [Track.ID] = []

    private var candidates: [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryStore.tracks.map { ($0.id, $0) })
        return candidateTrackIDs.compactMap { tracksByID[$0] }
    }

    var body: some View {
        List {
            Section {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "候補の曲がありません",
                        systemImage: "shuffle.circle",
                        description: Text("ジャンルが設定された曲をライブラリに追加してください。")
                    )
                } else {
                    ForEach(candidates) { track in
                        Button {
                            startPlayback(with: track)
                        } label: {
                            TrackRowView(track: track)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("この曲から同じジャンルのランダム再生を開始")
                    }
                }
            } header: {
                Text("最初に流す曲を選択")
            } footer: {
                Text("選んだ曲のあとに、同じジャンルの曲がランダムに再生されます。")
            }
        }
        .navigationTitle("選択してランダム再生")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("再抽選", systemImage: "arrow.clockwise") {
                    refreshCandidates()
                }
                .disabled(candidateTrackIDs.isEmpty)
            }
        }
        .task(id: libraryStore.tracks.map(\.id)) {
            refreshCandidates()
        }
    }

    private func refreshCandidates() {
        candidateTrackIDs = playbackHistoryStore
            .selectiveRandomCandidates(from: libraryStore.tracks, limit: 7)
            .map(\.id)
    }

    private func startPlayback(with track: Track) {
        let queue = playbackHistoryStore.genreRandomTracks(
            startingWith: track,
            from: libraryStore.tracks
        )
        guard !queue.isEmpty else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            queue,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: .shuffle)
        )
    }
}
