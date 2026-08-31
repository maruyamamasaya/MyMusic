import SwiftUI

struct MusicHistoryMonthView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    let month: MusicHistorySnapshot.Month
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    private var playbackTracks: [Track] {
        MusicHistoryService().tracksForMonth(
            month,
            availableTracks: libraryStore.unfilteredTracks
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let topTrack = month.mostPlayedTrack {
                    if let history = trackHistories[topTrack.track.id] {
                        NavigationLink {
                            TrackMusicHistoryView(summary: history)
                        } label: {
                            MusicHistoryHeroView(
                                eyebrow: "この月の1曲",
                                item: topTrack,
                                artworkMaxWidth: 270
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                MusicHistoryPlaybackButton(
                    isDisabled: playbackTracks.isEmpty,
                    action: playThisPeriod
                )
                .padding(.horizontal, 16)

                summarySection
                tracksSection
                artistsSection
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(month.date.formatted(.dateTime.year().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playThisPeriod() {
        let tracks = playbackTracks
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            tracks,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: .history)
        )
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(title: "この月の記録", subtitle: "聴き方をコンパクトに振り返る")
            MusicHistoryMetricsView(metrics: [
                MusicHistoryMetric(title: "再生", value: month.playCount, unit: "回"),
                MusicHistoryMetric(title: "曲", value: month.trackCount, unit: "曲"),
                MusicHistoryMetric(title: "アーティスト", value: month.artistCount, unit: "組")
            ])
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var tracksSection: some View {
        if !month.topTracks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MusicHistorySectionHeader(title: "よく聴いた曲", subtitle: "この月のTOP10")

                LazyVStack(spacing: 0) {
                    ForEach(Array(month.topTracks.enumerated()), id: \.element.id) { index, item in
                        if let history = trackHistories[item.track.id] {
                            NavigationLink {
                                TrackMusicHistoryView(summary: history)
                            } label: {
                                MusicHistoryTrackRow(rank: index + 1, item: item)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            MusicHistoryTrackRow(rank: index + 1, item: item)
                                .padding(.vertical, 8)
                        }
                        if item.id != month.topTracks.last?.id {
                            Divider().padding(.leading, 90)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private var artistsSection: some View {
        if !month.topArtists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MusicHistorySectionHeader(title: "よく聴いたアーティスト", subtitle: "この月のTOP10")

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(month.topArtists) { item in
                            MusicHistoryArtistTile(item: item, width: 136)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}
