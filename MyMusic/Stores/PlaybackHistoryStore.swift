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

    func recordPlaybackStarted(
        trackID: Track.ID,
        isRepeatModeActive: Bool,
        isConsecutivePlay: Bool
    ) {
        var entry = entry(for: trackID)
        entry.lastPlayedAt = Date()
        entry.consecutivePlayCount = isConsecutivePlay ? entry.consecutivePlayCount + 1 : 1
        if isRepeatModeActive { entry.repeatPlaybackCount += 1 }
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

    func addPlaybackDuration(trackID: Track.ID, seconds: TimeInterval) {
        guard seconds > 0 else { return }
        var entry = entry(for: trackID)
        entry.totalPlaybackDuration += seconds
        entries[trackID] = entry
        persist()
    }

    func recordPlaybackFinished(
        trackID: Track.ID,
        isFullPlayback: Bool,
        isSkipped: Bool
    ) {
        var entry = entry(for: trackID)
        if isFullPlayback { entry.fullPlaybackCount += 1 }
        if isSkipped { entry.skipCount += 1 }
        entries[trackID] = entry
        persist()
    }

    /// Clears only the playback facts for one track while preserving unrelated
    /// user choices such as favorites, preference ratings, and shuffle hiding.
    func resetPlaybackHistory(for trackID: Track.ID) {
        guard var entry = entries[trackID],
              entry.playCount > 0 || entry.lastPlayedAt != nil || !entry.playbackEvents.isEmpty ||
              entry.totalPlaybackDuration > 0 || entry.skipCount > 0 || entry.fullPlaybackCount > 0 ||
              entry.consecutivePlayCount > 0 || entry.repeatPlaybackCount > 0 else {
            return
        }
        entry.playCount = 0
        entry.lastPlayedAt = nil
        entry.playbackEvents.removeAll()
        entry.totalPlaybackDuration = 0
        entry.skipCount = 0
        entry.fullPlaybackCount = 0
        entry.consecutivePlayCount = 0
        entry.repeatPlaybackCount = 0
        entries[trackID] = entry
        persist()
    }

    func recentTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        resolvedTracks(from: tracks.filter(\.isEligibleForRegularPlayback)) { $0.lastPlayedAt != nil }
            .sorted { (entries[$0.id]?.lastPlayedAt ?? .distantPast) > (entries[$1.id]?.lastPlayedAt ?? .distantPast) }
            .limited(to: limit)
    }

    func favoriteTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        resolvedTracks(from: tracks.filter(\.isEligibleForRegularPlayback)) { $0.isFavorite }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .limited(to: limit)
    }

    func playCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.playCount ?? 0
    }

    func playbackPreference(for trackID: Track.ID) -> Int {
        entries[trackID]?.playbackPreference ?? 0
    }

    func totalPlaybackDuration(for trackID: Track.ID) -> TimeInterval {
        entries[trackID]?.totalPlaybackDuration ?? 0
    }

    func lastPlayedAt(for trackID: Track.ID) -> Date? {
        entries[trackID]?.lastPlayedAt
    }

    func skipCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.skipCount ?? 0
    }

    func fullPlaybackCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.fullPlaybackCount ?? 0
    }

    func consecutivePlayCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.consecutivePlayCount ?? 0
    }

    func repeatPlaybackCount(for trackID: Track.ID) -> Int {
        entries[trackID]?.repeatPlaybackCount ?? 0
    }

    func skipRate(for trackID: Track.ID) -> Double {
        let fullPlaybackCount = fullPlaybackCount(for: trackID)
        return PlaybackHistoryScoring.skipRate(
            fullPlaybackCount: fullPlaybackCount,
            skipCount: skipCount(for: trackID)
        )
    }

    func completionRate(for trackID: Track.ID) -> Double {
        let fullPlaybackCount = fullPlaybackCount(for: trackID)
        return PlaybackHistoryScoring.completionRate(
            fullPlaybackCount: fullPlaybackCount,
            skipCount: skipCount(for: trackID)
        )
    }

    func increasePlaybackPreference(for trackID: Track.ID) {
        adjustPlaybackPreference(for: trackID, by: 1)
    }

    func decreasePlaybackPreference(for trackID: Track.ID) {
        adjustPlaybackPreference(for: trackID, by: -1)
    }

    func boredomLevel(for trackID: Track.ID) -> Int {
        guard let entry = entries[trackID] else { return 0 }
        if entry.isPermanentlyHiddenFromShuffle { return 3 }
        return min(entry.boredomCount, 2)
    }

    func markBored(for trackID: Track.ID, now: Date = Date()) {
        var entry = entry(for: trackID)
        entry.boredomCount += 1
        let days = entry.boredomCount == 1 ? 1 : 7
        entry.boredomHiddenUntil = Calendar.current.date(byAdding: .day, value: days, to: now)
        entry.isPermanentlyHiddenFromShuffle = false
        entries[trackID] = entry
        persist()
    }

    func permanentlyHideFromShuffle(trackID: Track.ID) {
        var entry = entry(for: trackID)
        entry.boredomCount = max(1, entry.boredomCount)
        entry.boredomHiddenUntil = nil
        entry.isPermanentlyHiddenFromShuffle = true
        entries[trackID] = entry
        persist()
    }

    func isHiddenFromShuffle(trackID: Track.ID, now: Date = Date()) -> Bool {
        guard let entry = entries[trackID] else { return false }
        return entry.isPermanentlyHiddenFromShuffle || (entry.boredomHiddenUntil.map { $0 > now } ?? false)
    }

    func isEligibleForRegularShuffle(_ track: Track) -> Bool {
        track.isEligibleForRegularPlayback && !isHiddenFromShuffle(trackID: track.id)
    }

    /// Returns every track once, ordered by a preference-weighted random draw.
    /// Positive preferences are more likely to appear early, while negative
    /// preferences use the reciprocal weight and remain eligible for playback.
    func preferenceWeightedShuffle(_ tracks: [Track]) -> [Track] {
        weightedShuffle(tracks.filter(isEligibleForRegularShuffle))
    }

    /// Work-playback tracks have their own playback entry point and stay out
    /// of the app's regular shuffle flows.
    func workPlaybackTracks(from tracks: [Track]) -> [Track] {
        weightedShuffle(tracks.filter(\.isEligibleForWorkPlayback))
    }

    private func weightedShuffle(_ tracks: [Track]) -> [Track] {
        tracks
            .filter { !isHiddenFromShuffle(trackID: $0.id) }
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

        let shuffleEligibleTracks = tracks.filter(isEligibleForRegularShuffle)
        let recentFavorites = shuffleEligibleTracks
            .filter { isFavorite(trackID: $0.id) }
            .sorted {
                (entries[$0.id]?.lastPlayedAt ?? .distantPast) >
                    (entries[$1.id]?.lastPlayedAt ?? .distantPast)
            }
        let otherTracks = shuffleEligibleTracks.filter { !isFavorite(trackID: $0.id) }
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

    /// Offers seed tracks for a user-selected, genre-based random queue.
    /// Each candidate has genres that are disjoint from every other candidate.
    func selectiveRandomCandidates(from tracks: [Track], limit: Int = 7) -> [Track] {
        guard limit > 0 else { return [] }
        let candidates = tracks.filter {
            !$0.normalizedGenreNames.isEmpty && isEligibleForRegularShuffle($0)
        }

        var selectedTracks: [Track] = []
        var selectedGenres: Set<String> = []

        for track in preferenceWeightedShuffle(candidates) {
            guard selectedGenres.isDisjoint(with: track.normalizedGenreNames) else { continue }
            selectedTracks.append(track)
            selectedGenres.formUnion(track.normalizedGenreNames)
            if selectedTracks.count == limit { break }
        }

        return selectedTracks
    }

    /// Places the selected track first, then randomizes tracks sharing at least
    /// one of its genres. Tracks without a matching genre are not included.
    func genreRandomTracks(startingWith selectedTrack: Track, from tracks: [Track]) -> [Track] {
        let selectedGenres = selectedTrack.normalizedGenreNames
        guard !selectedGenres.isEmpty, isEligibleForRegularShuffle(selectedTrack) else { return [] }

        let relatedTracks = tracks.filter {
            $0.id != selectedTrack.id
                && isEligibleForRegularShuffle($0)
                && !$0.normalizedGenreNames.isDisjoint(with: selectedGenres)
        }
        return [selectedTrack] + preferenceWeightedShuffle(relatedTracks)
    }

    func repeatPlayTracks(from tracks: [Track], limit: Int = 30) -> [Track] {
        let candidates = tracks.filter {
            $0.isEligibleForRegularPlayback
                && playCount(for: $0.id) >= Self.repeatPlayMinimumCount
        }
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
