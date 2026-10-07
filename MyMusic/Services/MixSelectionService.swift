import Foundation

nonisolated enum MixKind: String, CaseIterable, Identifiable, Sendable {
    case daily
    case rediscovery
    case favorites
    case flow
    case timeCapsule

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Daily Mix"
        case .rediscovery: "Rediscovery Mix"
        case .favorites: "My Favorites Mix"
        case .flow: "Flow Mix"
        case .timeCapsule: "Time Capsule"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "いつもの曲と、新しい出会い"
        case .rediscovery: "しばらく聴いていない曲"
        case .favorites: "FavoriteとGoodから"
        case .flow: "音の近さでなめらかにつなぐ"
        case .timeCapsule: "あの季節に聴いた曲"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max.fill"
        case .rediscovery: "clock.arrow.circlepath"
        case .favorites: "heart.fill"
        case .flow: "waveform.path.ecg"
        case .timeCapsule: "archivebox.fill"
        }
    }

    var artworkName: String? {
        switch self {
        case .daily: "DailyMixArtwork"
        case .favorites: "FavoritesMixArtwork"
        case .flow: "FlowMixArtwork"
        case .timeCapsule: "TimeCapsuleMixArtwork"
        case .rediscovery: nil
        }
    }

    var hidesWhenEmpty: Bool {
        switch self {
        case .rediscovery, .flow, .timeCapsule: true
        case .daily, .favorites: false
        }
    }
}

/// Builds temporary queues from already loaded library, history and preferences.
/// The same inputs, local day and selection seed produce the same order.
nonisolated struct MixSelectionService {
    static let maximumCount = 25

    func tracks(
        for kind: MixKind,
        from candidates: [Track],
        histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference],
        weights: [Track.ID: Double],
        features: [Track.ID: TrackFeatureValues] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Track] {
        select(kind, from: ranked(candidates, weights: weights, now: now, calendar: calendar),
               histories: histories, preferences: preferences, features: features,
               now: now, calendar: calendar)
    }

    func allQueues(
        from candidates: [Track],
        histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference],
        weights: [Track.ID: Double],
        features: [Track.ID: TrackFeatureValues] = [:],
        now: Date = Date(),
        calendar: Calendar = .current,
        selectionSeed: UInt64 = 0
    ) -> [MixKind: [Track]] {
        let ordered = ranked(candidates, weights: weights, now: now, calendar: calendar, selectionSeed: selectionSeed)
        return Dictionary(uniqueKeysWithValues: MixKind.allCases.map { kind in
            (kind, select(kind, from: ordered, histories: histories,
                          preferences: preferences, features: features,
                          now: now, calendar: calendar))
        })
    }

    func ranked(
        _ candidates: [Track], weights: [Track.ID: Double], now: Date, calendar: Calendar, selectionSeed: UInt64 = 0
    ) -> [Track] {
        let day = calendar.startOfDay(for: now)
        let keys = Dictionary(uniqueKeysWithValues: candidates.map {
            ($0.id, drawKey(for: $0.id, day: day, weight: weights[$0.id] ?? 1, selectionSeed: selectionSeed))
        })
        return candidates.sorted {
            let left = keys[$0.id] ?? 0
            let right = keys[$1.id] ?? 0
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }
    }

    private func select(
        _ kind: MixKind, from sorted: [Track], histories: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference], features: [Track.ID: TrackFeatureValues],
        now: Date, calendar: Calendar
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
        case .flow:
            return flowTracks(from: sorted, histories: histories, features: features)
        case .timeCapsule:
            return timeCapsuleTracks(from: sorted, histories: histories, now: now, calendar: calendar)
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

    private func flowTracks(
        from sorted: [Track],
        histories: [Track.ID: PlaybackHistory],
        features: [Track.ID: TrackFeatureValues]
    ) -> [Track] {
        let candidates = sorted.filter { track in
            guard let values = features[track.id] else { return false }
            return flowVector(values).count >= 2
        }
        guard candidates.count >= 3 else { return [] }

        let rank = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($1.id, $0) })
        let seed = candidates.max { left, right in
            let leftDate = histories[left.id]?.lastPlayedAt ?? .distantPast
            let rightDate = histories[right.id]?.lastPlayedAt ?? .distantPast
            if leftDate != rightDate { return leftDate < rightDate }
            return (rank[left.id] ?? .max) > (rank[right.id] ?? .max)
        } ?? candidates[0]

        var result = [seed]
        var remaining = candidates.filter { $0.id != seed.id }
        while result.count < Self.maximumCount, let previous = result.last {
            let recent = result.suffix(3)
            guard let next = remaining.min(by: { left, right in
                flowScore(left, after: previous, recent: recent, features: features, rank: rank)
                    < flowScore(right, after: previous, recent: recent, features: features, rank: rank)
            }) else { break }
            result.append(next)
            remaining.removeAll { $0.id == next.id }
        }
        return result
    }

    private func flowScore(
        _ candidate: Track,
        after previous: Track,
        recent: ArraySlice<Track>,
        features: [Track.ID: TrackFeatureValues],
        rank: [Track.ID: Int]
    ) -> Double {
        let distance = featureDistance(features[previous.id], features[candidate.id]) ?? 1
        let normalizedArtist = candidate.artistName.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        )
        let normalizedAlbum = candidate.albumTitle?.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        )
        let artistPenalty = recent.last.map {
            $0.artistName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                == normalizedArtist ? 0.25 : 0
        } ?? 0
        let recentArtistPenalty = recent.dropLast().contains {
            $0.artistName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                == normalizedArtist
        } ? 0.08 : 0
        let previousAlbum = recent.last?.albumTitle?.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current
        )
        let albumPenalty = normalizedAlbum != nil && previousAlbum == normalizedAlbum ? 0.18 : 0
        let rankBias = Double(rank[candidate.id] ?? 0) * 0.000_001
        return distance + artistPenalty + recentArtistPenalty + albumPenalty + rankBias
    }

    private func flowVector(_ values: TrackFeatureValues) -> [Double] {
        [values.energy, values.calm, values.aggressive, values.bright, values.dark,
         values.ambient, values.electronic, values.piano, values.drumAndBass,
         values.vocal, values.instrumental]
            .compactMap { value in
                guard let value, value.isFinite, (0...1).contains(value) else { return nil }
                return value
            }
    }

    private func featureDistance(_ lhs: TrackFeatureValues?, _ rhs: TrackFeatureValues?) -> Double? {
        guard let lhs, let rhs else { return nil }
        let pairs: [(Double?, Double?)] = [
            (lhs.energy, rhs.energy), (lhs.calm, rhs.calm),
            (lhs.aggressive, rhs.aggressive), (lhs.bright, rhs.bright),
            (lhs.dark, rhs.dark), (lhs.ambient, rhs.ambient),
            (lhs.electronic, rhs.electronic), (lhs.piano, rhs.piano),
            (lhs.drumAndBass, rhs.drumAndBass), (lhs.vocal, rhs.vocal),
            (lhs.instrumental, rhs.instrumental)
        ]
        let differences = pairs.compactMap { left, right -> Double? in
            guard let left, let right, left.isFinite, right.isFinite,
                  (0...1).contains(left), (0...1).contains(right) else { return nil }
            return left - right
        }
        guard differences.count >= 2 else { return nil }
        return sqrt(differences.reduce(0) { $0 + $1 * $1 } / Double(differences.count))
    }

    private func timeCapsuleTracks(
        from sorted: [Track],
        histories: [Track.ID: PlaybackHistory],
        now: Date,
        calendar: Calendar
    ) -> [Track] {
        let recentCutoff = calendar.date(byAdding: .day, value: -60, to: now) ?? now
        let anniversaryTargets = (1...3).compactMap {
            calendar.date(byAdding: .year, value: -$0, to: now)
        }
        let window: TimeInterval = 45 * 86_400
        let rank = Dictionary(uniqueKeysWithValues: sorted.enumerated().map { ($1.id, $0) })
        let matches = sorted.compactMap { track -> (track: Track, distance: TimeInterval)? in
            guard let history = histories[track.id],
                  (history.lastPlayedAt ?? .distantPast) < recentCutoff else { return nil }
            var dates = history.playbackEvents.map(\.startedAt)
            if dates.isEmpty {
                dates = [history.firstPlayedAt, history.lastPlayedAt].compactMap { $0 }
            }
            guard let distance = dates.flatMap({ date in
                anniversaryTargets.map { abs(date.timeIntervalSince($0)) }
            }).min(), distance <= window else { return nil }
            return (track, distance)
        }
        return Array(matches.sorted { left, right in
            if left.distance != right.distance { return left.distance < right.distance }
            return (rank[left.track.id] ?? .max) < (rank[right.track.id] ?? .max)
        }.prefix(Self.maximumCount).map(\.track))
    }

    private func isFavorite(_ track: Track, preferences: [Track.ID: TrackPreference]) -> Bool {
        let preference = preferences[track.id]
        return preference?.favorite == true || (preference?.playbackPreference ?? 0) > 0
    }

    private func drawKey(for id: Track.ID, day: Date, weight: Double, selectionSeed: UInt64 = 0) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let base = "\(Int(day.timeIntervalSince1970)):\(id.uuidString)"
        let key = selectionSeed == 0 ? base : "\(base):\(selectionSeed)"
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        if selectionSeed != 0 {
            // Avalanche the seeded hash so nearby seeds redraw the weighted ranking.
            hash = (hash ^ (hash >> 30)) &* 0xbf58476d1ce4e5b9
            hash = (hash ^ (hash >> 27)) &* 0x94d049bb133111eb
            hash ^= hash >> 31
        }
        let unit = (Double(hash) + 1) / (Double(UInt64.max) + 2)
        return -log(unit) / max(weight.isFinite ? weight : 1, 0.01)
    }
}
