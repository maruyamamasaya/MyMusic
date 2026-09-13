import SwiftUI

struct ListenLaterView: View {
    @Environment(ListenLaterStore.self) private var listenLaterStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore

    private var tracks: [Track] {
        listenLaterStore.tracks(in: libraryStore.tracks)
    }

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "あとで聴く曲はありません",
                    systemImage: "text.badge.plus",
                    description: Text("再生中画面の＋ボタンから曲を追加できます。")
                )
            } else {
                Section {
                    PlayShuffleButtons(
                        isDisabled: false,
                        onPlay: { play(shuffled: false) },
                        onShuffle: { play(shuffled: true) }
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("曲") {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        PlayableTrackRowView(track: track) {
                            play(startingAt: index)
                        }
                        .swipeActions {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                listenLaterStore.remove(track.id)
                            }
                        }
                    }
                }
            }
        }
        .themeScreen()
        .navigationTitle("あとで聴く")
    }

    private func play(shuffled: Bool) {
        let queue = shuffled ? tracks.shuffled() : tracks
        guard !queue.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(
            queue,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: .playlist)
        )
    }

    private func play(startingAt index: Int) {
        guard tracks.indices.contains(index) else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            tracks,
            startingAt: index,
            startContext: PlaybackStartContext(kind: .manual, source: .playlist)
        )
    }
}
