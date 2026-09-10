import SwiftUI

struct MusicHistoryRankingView: View {
    enum Ranking {
        case tracks([MusicHistorySnapshot.TrackRanking])
        case artists([MusicHistorySnapshot.ArtistRanking])
    }

    let title: String
    let periodDescription: String
    let ranking: Ranking
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(periodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)

                switch ranking {
                case .tracks(let items):
                    trackRows(items)
                case .artists(let items):
                    artistRows(items)
                }
            }
            .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func trackRows(_ items: [MusicHistorySnapshot.TrackRanking]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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

            if index < items.count - 1 {
                Divider().padding(.leading, 90)
            }
        }
    }

    @ViewBuilder
    private func artistRows(_ items: [MusicHistorySnapshot.ArtistRanking]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            MusicHistoryArtistRow(rank: index + 1, item: item)
                .padding(.vertical, 8)

            if index < items.count - 1 {
                Divider().padding(.leading, 90)
            }
        }
    }
}
