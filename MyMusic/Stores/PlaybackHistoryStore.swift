import Foundation
import Observation

@MainActor
@Observable
final class PlaybackHistoryStore {
    private static let repeatPlayMinimumCount = 2
    static let maximumPreference = 10

    private(set) var entries: [Track.ID: PlaybackHistory] = [:]
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let persistence: PlaybackHistoryPersistenceServicing
    private var saveTask: Task<Void, Never>?
    private var isLoading = false

    init(persistence: PlaybackHistoryPersistenceServicing? = nil) {
        self.persistence = persistence ?? PlaybackHistoryPersistenceService()
    }

    func loadIfNeeded() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            isLoaded = true
        }
        do {
            let loaded = try await persistence.load()
            var merged = Dictionary(uniqueKeysWithValues: loaded.map { ($0.trackID, $0) })
            // Preserve favorites or playback events recorded while disk loading was in flight.
            for (trackID, currentEntry) in entries {
                merged[trackID] = currentEntry
            }
            entries = merged
        } catch {
            errorMessage = "再生履歴を読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func isFavorite(trackID: Track.ID) -> Bool {
        entries[trackID]?.isFavorite == true
    }

    func toggleFavorite(trackID: Track.ID) {
        var entry = entry(for: trackID)
        entry.isFavorite.toggle()
        entries[trackID] = entry
        persist()
    }

    func recordPlaybackStarted(trackID: Track.ID) {
        var entry = entry(for: trackID)
        entry.lastPlayedAt = Date()
        entries[trackID] = entry
        persist()
    }

    func recordPlaybackCompleted(trackID: Track.ID) {
        var entry = entry(for: trackID)
        entry.playCount += 1
        entry.playbackEvents.append(Date())
        entries[trackID] = entry
        persist()
    }

    func recentTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        resolvedTracks(from: tracks) { $0.lastPlayedAt != nil }
            .sorted { (entries[$0.id]?.lastPlayedAt ?? .distantPast) > (entries[$1.id]?.lastPlayedAt ?? .distantPast) }
            .limited(to: limit)
    }

    func favoriteTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        resolvedTracks(from: tracks) { $0.isFavorite }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .limited(to: limit)
    }

    func playCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.playCount ?? 0
    }

    func playbackPreference(for trackID: Track.ID) -> Int {
        entries[trackID]?.playbackPreference ?? 0
    }

    func increasePlaybackPreference(for trackID: Track.ID) {
        adjustPlaybackPreference(for: trackID, by: 1)
    }

    func decreasePlaybackPreference(for trackID: Track.ID) {
        adjustPlaybackPreference(for: trackID, by: -1)
    }

    /// Returns every track once, ordered by a preference-weighted random draw.
    /// Positive preferences are more likely to appear early, while negative
    /// preferences use the reciprocal weight and remain eligible for playback.
    func preferenceWeightedShuffle(_ tracks: [Track]) -> [Track] {
        tracks
            .map { track in
                let unitRandom = Double.random(in: Double.leastNonzeroMagnitude ... 1)
                let key = -log(unitRandom) / playbackSelectionWeight(for: track.id)
                return (track: track, key: key)
            }
            .sorted { $0.key < $1.key }
            .map(\.track)
    }

    func quickPlayTracks(from tracks: [Track], limit: Int = 30) -> [Track] {
        guard limit > 0 else { return [] }

        let recentFavorites = tracks
            .filter { isFavorite(trackID: $0.id) }
            .sorted {
                (entries[$0.id]?.lastPlayedAt ?? .distantPast) >
                    (entries[$1.id]?.lastPlayedAt ?? .distantPast)
            }
        let otherTracks = tracks.filter { !isFavorite(trackID: $0.id) }
        let pairCount = min(limit / 2, recentFavorites.count, otherTracks.count)

        guard pairCount > 0 else {
            return Array(preferenceWeightedShuffle(recentFavorites + otherTracks).prefix(limit))
        }

        let favorites = preferenceWeightedShuffle(Array(recentFavorites.prefix(pairCount)))
        let others = Array(preferenceWeightedShuffle(otherTracks).prefix(pairCount))
        return zip(favorites, others).flatMap { [$0, $1] }
    }

    func discoveryPlayTracks(from tracks: [Track], limit: Int = 30) -> [Track] {
        Array(preferenceWeightedShuffle(tracks.filter { playCount(for: $0.id) == 0 }).prefix(limit))
    }

    func repeatPlayTracks(from tracks: [Track], limit: Int = 30) -> [Track] {
        let candidates = tracks.filter { playCount(for: $0.id) >= Self.repeatPlayMinimumCount }
        return Array(preferenceWeightedShuffle(candidates).prefix(limit))
    }

    func mostPlayedTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        tracks
            .filter { playCount(for: $0.id) > 0 }
            .sorted {
                let lhsCount = playCount(for: $0.id)
                let rhsCount = playCount(for: $1.id)
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            .limited(to: limit)
    }

    func dismissError() { errorMessage = nil }

    private func adjustPlaybackPreference(for trackID: Track.ID, by adjustment: Int) {
        var entry = entry(for: trackID)
        entry.playbackPreference = min(
            Self.maximumPreference,
            max(-Self.maximumPreference, entry.playbackPreference + adjustment)
        )
        entries[trackID] = entry
        persist()
    }

    func playbackSelectionWeight(for trackID: Track.ID) -> Double {
        let preference = playbackPreference(for: trackID)
        if preference > 0 { return Double(preference + 1) }
        if preference < 0 { return 1 / Double(abs(preference) + 1) }
        return 1
    }

    private func entry(for trackID: Track.ID) -> PlaybackHistory {
        entries[trackID] ?? PlaybackHistory(trackID: trackID, isFavorite: false, playCount: 0, lastPlayedAt: nil)
    }

    private func resolvedTracks(from tracks: [Track], matching predicate: (PlaybackHistory) -> Bool) -> [Track] {
        tracks.filter { track in entries[track.id].map(predicate) == true }
    }

    private func persist() {
        let snapshot = Array(entries.values)
        saveTask?.cancel()
        saveTask = Task { [weak self, persistence] in
            do {
                try await persistence.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = "再生履歴を保存できませんでした: \(error.localizedDescription)"
            }
        }
    }
}

private extension Array {
    func limited(to limit: Int?) -> [Element] {
        guard let limit else { return self }
        return Array(prefix(limit))
    }
}
