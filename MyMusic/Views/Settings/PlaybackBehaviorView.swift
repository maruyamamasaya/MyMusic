import SwiftUI

struct PlaybackBehaviorView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    private let analyzer = PlaybackBehaviorAnalyzer()

    private var analysis: PlaybackBehaviorAnalysis {
        analyzer.analyze(tracks: libraryStore.tracks, historyByTrackID: playbackHistoryStore.entries)
    }

    var body: some View {
        List {
            Section("聴きすぎている曲") {
                if analysis.overplayCandidates.isEmpty {
                    Text("現在、強い聴きすぎ傾向はありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(analysis.overplayCandidates) { result in
                        BehaviorTrackHeader(track: result.track) {
                            LabeledContent("直近7日", value: "\(result.score.recentPlayCount)回")
                            LabeledContent(
                                "通常週平均",
                                value: result.score.weeklyBaseline.formatted(.number.precision(.fractionLength(1))) + "回"
                            )
                            Label("聴きすぎ傾向", systemImage: "repeat.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Good評価と最近の行動がずれている曲") {
                if analysis.preferenceDriftCandidates.isEmpty {
                    Text("現在、確認が必要なずれはありません。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(analysis.preferenceDriftCandidates) { result in
                        BehaviorTrackHeader(track: result.track) {
                            LabeledContent("現在のGood値", value: "+\(result.playbackPreference)")
                            LabeledContent("過去完走率", value: percent(result.score.historicalCompletionRate ?? 0))
                            LabeledContent("直近30日完走率", value: percent(result.score.recentCompletionRate))
                            LabeledContent("直近30日skip", value: "\(result.score.recentSkipCount)回")
                            Label("行動のずれを確認", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                                .foregroundStyle(.orange)
                            HStack {
                                Spacer()
                                PlaybackPreferenceButton(track: result.track, direction: .decrease, compact: true)
                                PlaybackPreferenceButton(track: result.track, direction: .increase, compact: true)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("再生傾向")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

private struct BehaviorTrackHeader<Details: View>: View {
    let track: Track
    @ViewBuilder let details: Details

    init(track: Track, @ViewBuilder details: () -> Details) {
        self.track = track
        self.details = details()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AlbumArtworkView(artworkIdentifier: track.artworkIdentifier)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.headline).lineLimit(2)
                Text(track.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Text(track.albumTitle ?? "アルバム不明").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                details
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}
