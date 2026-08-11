import SwiftUI

struct AnalyticsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService().makeSnapshot(
            tracks: libraryStore.tracks,
            historyEntries: playbackHistoryStore.entries,
            playlists: playlistStore.playlists
        )
    }

    var body: some View {
        List {
            overviewSection
            playbackHistorySection
            mostPlayedSection
            playCountsSection
            recentTracksSection
            favoritesSection
            playlistsSection
        }
        .navigationTitle("分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewSection: some View {
        Section("概要") {
            LabeledContent("総再生回数", value: "\(snapshot.totalPlayCount)回")
            LabeledContent("再生した楽曲数", value: "\(snapshot.playedTrackCount)曲")
            LabeledContent("お気に入り数", value: "\(snapshot.favoriteCount)曲")
            LabeledContent("プレイリスト数", value: "\(snapshot.playlistCount)件")

            if let item = snapshot.mostPlayedTrack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最も再生した曲")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.track.title)
                    Text("\(item.track.artistName) • \(item.playCount)回")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var playbackHistorySection: some View {
        Section("再生履歴") {
            if snapshot.playbackHistory.isEmpty {
                emptyMessage("再生履歴はありません。")
            } else {
                ForEach(snapshot.playbackHistory) { item in
                    historyRow(item)
                }
            }
        }
    }

    private var mostPlayedSection: some View {
        Section("よく再生している曲") {
            if snapshot.mostPlayedTracks.isEmpty {
                emptyMessage("再生回数の記録はありません。")
            } else {
                ForEach(snapshot.mostPlayedTracks) { item in
                    playCountRow(item)
                }
            }
        }
    }

    private var playCountsSection: some View {
        Section("楽曲ごとの再生回数") {
            if snapshot.trackPlayCounts.isEmpty {
                emptyMessage("再生回数の記録はありません。")
            } else {
                ForEach(snapshot.trackPlayCounts) { item in
                    playCountRow(item)
                }
            }
        }
    }

    private var recentTracksSection: some View {
        Section("最近再生した曲") {
            if snapshot.recentTracks.isEmpty {
                emptyMessage("最近再生した曲はありません。")
            } else {
                ForEach(snapshot.recentTracks) { item in
                    historyRow(item)
                }
            }
        }
    }

    private var favoritesSection: some View {
        Section("お気に入りの曲") {
            if snapshot.favoriteTracks.isEmpty {
                emptyMessage("お気に入りはありません。")
            } else {
                ForEach(snapshot.favoriteTracks) { item in
                    trackSummary(item.track)
                }
            }
        }
    }

    private var playlistsSection: some View {
        Section("プレイリスト情報") {
            LabeledContent("プレイリスト数", value: "\(snapshot.playlistCount)件")

            if snapshot.playlists.isEmpty {
                emptyMessage("プレイリストはありません。")
            } else {
                ForEach(snapshot.playlists) { playlist in
                    LabeledContent(playlist.name, value: "\(playlist.trackCount)曲")
                }
            }
        }
    }

    private func historyRow(_ item: AnalyticsSnapshot.TrackItem) -> some View {
        HStack(alignment: .firstTextBaseline) {
            trackSummary(item.track)
            Spacer()
            if let lastPlayedAt = item.lastPlayedAt {
                Text(lastPlayedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func playCountRow(_ item: AnalyticsSnapshot.TrackItem) -> some View {
        HStack(alignment: .firstTextBaseline) {
            trackSummary(item.track)
            Spacer()
            Text("\(item.playCount)回")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func trackSummary(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .lineLimit(1)
            Text(track.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
    }
}
