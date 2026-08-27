import SwiftUI

struct MusicHistoryMonthView: View {
    let month: MusicHistorySnapshot.Month

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let topTrack = month.mostPlayedTrack {
                    MusicHistoryHeroView(
                        eyebrow: "この月の1曲",
                        item: topTrack,
                        artworkMaxWidth: 270
                    )
                    .padding(.horizontal, 16)
                }

                summarySection
                tracksSection
                artistsSection
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(month.date.formatted(.dateTime.year().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
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
                        MusicHistoryTrackRow(rank: index + 1, item: item)
                            .padding(.vertical, 8)
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
