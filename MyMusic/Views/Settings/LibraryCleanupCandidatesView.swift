import SwiftUI

struct LibraryCleanupCandidatesView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(TrackPreferenceStore.self) private var trackPreferenceStore

    private let service = LibraryCleanupCandidateService()

    private var candidates: [LibraryCleanupCandidate] {
        service.candidates(
            tracks: libraryStore.tracks,
            historyByTrackID: playbackHistoryStore.entries,
            preferencesByTrackID: trackPreferenceStore.entries
        )
    }

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView(
                    "整理候補はありません",
                    systemImage: "checkmark.circle",
                    description: Text("直近の再生で、途中スキップが半数以上かつ平均再生率が10%以下の曲を表示します。")
                )
            } else {
                List(candidates) { candidate in
                    LibraryCleanupCandidateRow(candidate: candidate)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("ライブラリ整理候補")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LibraryCleanupCandidateRow: View {
    let candidate: LibraryCleanupCandidate

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AlbumArtworkView(artworkIdentifier: candidate.track.artworkIdentifier)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.track.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(candidate.track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(candidate.track.albumTitle ?? "アルバム不明")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("途中スキップ \(candidate.userSkipCount)/\(candidate.evaluatedEventCount)回（\(percent(candidate.userSkipRate))）")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.orange)

                Text("平均再生率 \(percent(candidate.averagePlaybackRatio))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                Text("最終再生: \(lastPlayedText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("現在の評価: \(preferenceText)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                    Spacer(minLength: 4)
                    PlaybackPreferenceButton(track: candidate.track, direction: .decrease, compact: true)
                    PlaybackPreferenceButton(track: candidate.track, direction: .increase, compact: true)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    private var lastPlayedText: String {
        guard let lastPlayedAt = candidate.lastPlayedAt else { return "記録なし" }
        return lastPlayedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var preferenceText: String {
        candidate.playbackPreference > 0 ? "+\(candidate.playbackPreference)" : "\(candidate.playbackPreference)"
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
