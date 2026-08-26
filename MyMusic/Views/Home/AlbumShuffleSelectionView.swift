import SwiftUI

struct AlbumShuffleSelectionView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    let title: String
    let albums: [Album]

    var body: some View {
        List {
            if albums.isEmpty {
                ContentUnavailableView(
                    "アルバムがありません",
                    systemImage: "square.stack",
                    description: Text("再生できるアルバムが見つかりませんでした。")
                )
            } else {
                Section {
                    Text("アルバムを選ぶと、そのアルバムをランダム再生します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("アルバム") {
                    ForEach(albums) { album in
                        let tracks = playableTracks(for: album)
                        Button {
                            play(tracks)
                        } label: {
                            HStack(spacing: 12) {
                                AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                    .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(album.title)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("\(album.artistName)・\(tracks.count)曲")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "shuffle")
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(tracks.isEmpty)
                        .accessibilityHint("このアルバムをランダム再生")
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playableTracks(for album: Album) -> [Track] {
        libraryStore.tracks(for: album).filter(playbackHistoryStore.isEligibleForRegularShuffle)
    }

    private func play(_ tracks: [Track]) {
        guard let startingIndex = tracks.indices.randomElement() else { return }
        playerStore.setShuffleEnabled(true)
        playerStore.playQueue(tracks, startingAt: startingIndex)
    }
}
