import Foundation

struct AnalyticsSnapshot {
    struct TrackItem: Identifiable {
        let track: Track
        let playCount: Int
        let lastPlayedAt: Date?
        let playbackPreference: Int
        var id: Track.ID { track.id }
    }

    struct PlaybackEvent: Identifiable {
        let id = UUID()
        let track: Track
        let playedAt: Date
    }

    struct DayGroup: Identifiable {
        let date: Date
        let events: [PlaybackEvent]
        var id: Date { date }
    }

    struct MonthGroup: Identifiable {
        let date: Date
        let days: [DayGroup]
        var id: Date { date }
        var eventCount: Int { days.reduce(0) { $0 + $1.events.count } }
    }

    let totalPlayCount: Int
    let playedTrackCount: Int
    let favoriteCount: Int
    let playlistCount: Int
    let mostPlayedTrack: TrackItem?
    let mostPlayedTracks: [TrackItem]
    let preferenceRatedTracks: [TrackItem]
    let playbackMonths: [MonthGroup]
}

@MainActor
final class AnalyticsService {
    func makeSnapshot(
        tracks: [Track],
        historyEntries: [Track.ID: PlaybackHistory],
        playlists: [Playlist]
    ) -> AnalyticsSnapshot {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let trackItems = tracks.map { track in
            let history = historyEntries[track.id]
            return AnalyticsSnapshot.TrackItem(
                track: track,
                playCount: history?.playCount ?? 0,
                lastPlayedAt: history?.lastPlayedAt,
                playbackPreference: history?.playbackPreference ?? 0
            )
        }
        let playCounts = trackItems.filter { $0.playCount > 0 }.sorted(by: playCountSort)
        let events = historyEntries.values.flatMap { history in
            guard let track = tracksByID[history.trackID] else { return [AnalyticsSnapshot.PlaybackEvent]() }
            return history.playbackEvents.map {
                AnalyticsSnapshot.PlaybackEvent(track: track, playedAt: $0)
            }
        }
        .sorted { $0.playedAt > $1.playedAt }

        return AnalyticsSnapshot(
            totalPlayCount: historyEntries.values.reduce(0) { $0 + $1.playCount },
            playedTrackCount: historyEntries.values.filter { $0.lastPlayedAt != nil }.count,
            favoriteCount: historyEntries.values.filter(\.isFavorite).count,
            playlistCount: playlists.count,
            mostPlayedTrack: playCounts.first,
            mostPlayedTracks: playCounts,
            preferenceRatedTracks: trackItems
                .filter { $0.playbackPreference != 0 }
                .sorted(by: titleSort),
            playbackMonths: groupedEvents(events)
        )
    }

    func csv(
        snapshot: AnalyticsSnapshot,
        playlists: [Playlist],
        equalizer: EqualizerSettings? = nil,
        customEqualizerPresets: [EqualizerPreset] = []
    ) -> String {
        var rows = ["種類,日時,曲名,アーティスト,再生回数,値"]
        for month in snapshot.playbackMonths {
            for day in month.days {
                for event in day.events {
                    rows.append(["再生履歴", Self.dateTimeFormatter.string(from: event.playedAt), event.track.title, event.track.artistName, "", ""].map(csvField).joined(separator: ","))
                }
            }
        }
        for item in snapshot.mostPlayedTracks {
            rows.append(["楽曲別再生回数", "", item.track.title, item.track.artistName, "\(item.playCount)", ""].map(csvField).joined(separator: ","))
        }
        for item in snapshot.preferenceRatedTracks {
            rows.append([
                "再生傾向評価",
                "",
                item.track.title,
                item.track.artistName,
                "",
                String(format: "%+d", item.playbackPreference)
            ].map(csvField).joined(separator: ","))
        }
        rows.append(["集計", "", "お気に入り", "", "", "\(snapshot.favoriteCount)"].map(csvField).joined(separator: ","))
        rows.append(["集計", "", "プレイリスト", "", "", "\(snapshot.playlistCount)"].map(csvField).joined(separator: ","))
        for playlist in playlists {
            rows.append(["プレイリスト", Self.dateTimeFormatter.string(from: playlist.updatedAt), playlist.name, "", "", "\(playlist.trackIDs.count)曲"].map(csvField).joined(separator: ","))
        }
        if let equalizer {
            rows.append(["EQ設定", "", "現在の設定", "", "", equalizer.isEnabled ? "ON" : "OFF"].map(csvField).joined(separator: ","))
            rows.append(["EQ設定", "", "現在の設定", "プリアンプ", "", Self.gainString(equalizer.preamp)].map(csvField).joined(separator: ","))
            appendEqualizerBands(equalizer.bands, type: "EQ設定", name: "現在の設定", to: &rows)
        }
        for preset in customEqualizerPresets {
            rows.append(["EQプリセット", "", preset.name, "プリアンプ", "", Self.gainString(preset.preamp)].map(csvField).joined(separator: ","))
            appendEqualizerBands(preset.settings().bands, type: "EQプリセット", name: preset.name, to: &rows)
        }
        return rows.joined(separator: "\n")
    }

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private func groupedEvents(_ events: [AnalyticsSnapshot.PlaybackEvent]) -> [AnalyticsSnapshot.MonthGroup] {
        let calendar = Calendar.current
        let months = Dictionary(grouping: events) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.playedAt))!
        }
        return months.map { month, monthEvents in
            let days = Dictionary(grouping: monthEvents) { calendar.startOfDay(for: $0.playedAt) }
                .map { AnalyticsSnapshot.DayGroup(date: $0.key, events: $0.value.sorted { $0.playedAt > $1.playedAt }) }
                .sorted { $0.date > $1.date }
            return AnalyticsSnapshot.MonthGroup(date: month, days: days)
        }
        .sorted { $0.date > $1.date }
    }

    private func playCountSort(_ lhs: AnalyticsSnapshot.TrackItem, _ rhs: AnalyticsSnapshot.TrackItem) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
    }

    private func titleSort(_ lhs: AnalyticsSnapshot.TrackItem, _ rhs: AnalyticsSnapshot.TrackItem) -> Bool {
        let titleComparison = lhs.track.title.localizedStandardCompare(rhs.track.title)
        if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
        return lhs.track.artistName.localizedStandardCompare(rhs.track.artistName) == .orderedAscending
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func appendEqualizerBands(_ bands: [EqualizerBand], type: String, name: String, to rows: inout [String]) {
        for band in bands {
            rows.append([type, "", name, "\(Int(band.frequency)) Hz", "", Self.gainString(band.gain)].map(csvField).joined(separator: ","))
        }
    }

    private static func gainString(_ gain: Float) -> String {
        String(format: "%+.1f dB", gain)
    }
}
