import SwiftUI

struct MusicHistoryTimeCapsuleView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    let capsules: [MusicHistoryTimeCapsuleSummary]
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    var body: some View {
        Group {
            if capsules.isEmpty {
                ContentUnavailableView(
                    "タイムカプセルはこれから育ちます",
                    systemImage: "archivebox",
                    description: Text("30日前や3か月前の履歴が増えると、その頃の音楽がここに現れます。")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(capsules) { capsule in
                            timeCapsule(capsule)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("タイムカプセル")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func timeCapsule(_ capsule: MusicHistoryTimeCapsuleSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(capsule.distance.title)
                    .font(.title3.weight(.bold))
                Text(capsule.targetDate, format: .dateTime.year().month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(capsule.topTracks) { item in
                        if let history = trackHistories[item.track.id] {
                            NavigationLink {
                                TrackMusicHistoryView(summary: history)
                            } label: {
                                MusicHistoryTrackTile(item: item, width: 142)
                            }
                            .buttonStyle(.plain)
                        } else {
                            MusicHistoryTrackTile(item: item, width: 142)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            if !capsule.topArtistNames.isEmpty {
                Text("この頃は、\(capsule.topArtistNames.joined(separator: " と "))をよく聴いていました。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            MusicHistoryPlaybackButton(
                isDisabled: playbackTracks(for: capsule).isEmpty,
                action: { play(capsule) }
            )
            .padding(.horizontal, 16)
        }
    }

    private func playbackTracks(for capsule: MusicHistoryTimeCapsuleSummary) -> [Track] {
        MusicHistoryService().tracksForTimeCapsule(
            capsule,
            availableTracks: libraryStore.unfilteredTracks
        )
    }

    private func play(_ capsule: MusicHistoryTimeCapsuleSummary) {
        let tracks = playbackTracks(for: capsule)
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            tracks,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: .history)
        )
    }
}
