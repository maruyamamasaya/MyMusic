import Foundation

nonisolated enum MixKind: String, CaseIterable, Identifiable, Sendable {
    case daily
    case rediscovery
    case favorites

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Daily Mix"
        case .rediscovery: "Rediscovery Mix"
        case .favorites: "My Favorites Mix"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "いつもの曲と、新しい出会い"
        case .rediscovery: "しばらく聴いていない曲"
        case .favorites: "FavoriteとGoodから"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max.fill"
        case .rediscovery: "clock.arrow.circlepath"
        case .favorites: "heart.fill"
        }
    }
}

/// Builds temporary queues from already loaded library, history and preferences.
/// The same inputs on the same local day produce the same order.
nonisolated struct MixSelectionService {
    static let maximumCount = 25

    func tracks(
        for kind: MixKind,
        from candidates: [Track],
        histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference],
        weights: [Track.ID: Double],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Track] {
        select(kind, from: ranked(candidates, weights: weights, now: now, calendar: calendar),
               histories: histories, preferences: preferences, now: now, calendar: calendar)
    }

    func allQueues(
        from candidates: [Track],
        histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference],
        weights: [Track.ID: Double],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MixKind: [Track]] {
        let ordered = ranked(candidates, weights: weights, now: now, calendar: calendar)
        return Dictionary(uniqueKeysWithValues: MixKind.allCases.map { kind in
            (kind, select(kind, from: ordered, histories: histories,
                          preferences: preferences, now: now, calendar: calendar))
        })
    }

    func ranked(
        _ candidates: [Track], weights: [Track.ID: Double], now: Date, calendar: Calendar
    ) -> [Track] {
        let day = calendar.startOfDay(for: now)
        let keys = Dictionary(uniqueKeysWithValues: candidates.map {
            ($0.id, drawKey(for: $0.id, day: day, weight: weights[$0.id] ?? 1))
        })
        return candidates.sorted {
            let left = keys[$0.id] ?? 0
            let right = keys[$1.id] ?? 0
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }
    }

    private func select(
        _ kind: MixKind, from sorted: [Track], histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference], now: Date, calendar: Calendar
    ) -> [Track] {
        switch kind {
        case .favorites:
            return Array(sorted.filter { isFavorite($0, preferences: preferences) }.prefix(Self.maximumCount))
        case .rediscovery:
            let cutoff = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            return Array(sorted.filter {
                guard let history = histories[$0.id], let lastPlayedAt = history.lastPlayedAt else { return false }
                return history.playCount >= 3 && lastPlayedAt < cutoff
            }.prefix(Self.maximumCount))
        case .daily:
            let recentCutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let oldCutoff = calendar.date(byAdding: .day, value: -60, to: now) ?? now
            let favoriteFrontIDs = Set(sorted.lazy.filter {
                isFavorite($0, preferences: preferences)
            }.prefix(Self.maximumCount).map(\.id))
            let dailyCandidates = sorted.filter { !favoriteFrontIDs.contains($0.id) }
            let groups: [[Track]] = [
                dailyCandidates.filter {
                    guard let history = histories[$0.id] else { return false }
                    return history.playCount >= 2 && (history.lastPlayedAt ?? .distantPast) >= recentCutoff
                },
                dailyCandidates.filter { (histories[$0.id]?.playCount ?? 0) <= 1 },
                dailyCandidates.filter {
                    guard let history = histories[$0.id], let lastPlayedAt = history.lastPlayedAt else { return false }
                    return history.playCount >= 3 && lastPlayedAt < oldCutoff
                },
                dailyCandidates.filter { isFavorite($0, preferences: preferences) }
            ]
            var result: [Track] = []
            var seen: Set<Track.ID> = []
            var positions = Array(repeating: 0, count: groups.count)
            while result.count < Self.maximumCount {
                var added = false
                for index in groups.indices {
                    while positions[index] < groups[index].count {
                        let track = groups[index][positions[index]]
                        positions[index] += 1
                        if seen.insert(track.id).inserted {
                            result.append(track)
                            added = true
                            break
                        }
                    }
                    if result.count == Self.maximumCount { break }
                }
                if !added { break }
            }
            for track in dailyCandidates where result.count < Self.maximumCount {
                if seen.insert(track.id).inserted { result.append(track) }
            }
            for track in sorted where result.count < Self.maximumCount && favoriteFrontIDs.contains(track.id) {
                result.append(track)
            }
            return result
        }
    }

    private func isFavorite(_ track: Track, preferences: [Track.ID: TrackPreference]) -> Bool {
        let preference = preferences[track.id]
        return preference?.favorite == true || (preference?.playbackPreference ?? 0) > 0
    }

    private func drawKey(for id: Track.ID, day: Date, weight: Double) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(Int(day.timeIntervalSince1970)):\(id.uuidString)".utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        let unit = (Double(hash) + 1) / (Double(UInt64.max) + 2)
        return -log(unit) / max(weight.isFinite ? weight : 1, 0.01)
    }
}
