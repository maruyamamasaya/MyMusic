import Foundation
import Observation

@MainActor
@Observable
final class TrackPreferenceStore {
    static let maximumPreference = PlaybackPreferenceWeightPolicy.maximumPreference

    private(set) var entries: [Track.ID: TrackPreference] = [:]
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let persistence: TrackPreferencePersistenceServicing
    private var saveTask: Task<Void, Never>?
    private var isLoading = false

    init(persistence: TrackPreferencePersistenceServicing = TrackPreferencePersistenceService()) {
        self.persistence = persistence
    }

    /// The absence of the v2 file is the one-time migration marker. Legacy values
    /// remain in PlaybackHistory for backward decoding, but are never authoritative afterward.
    func loadIfNeeded(legacyHistory: [Track.ID: PlaybackHistory]?) async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let hadPendingChanges = !entries.isEmpty
            let loaded: [TrackPreference]
            if let existing = try await persistence.load() {
                loaded = existing
            } else {
                guard let legacyHistory else { return }
                loaded = legacyHistory.values.map {
                    TrackPreference(
                        trackID: $0.trackID,
                        playbackPreference: Self.clamped($0.playbackPreference),
                        favorite: $0.isFavorite
                    )
                }
                try await persistence.save(loaded)
                guard let verified = try await persistence.load(), verified == loaded.sorted(by: Self.sort) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
            var merged: [Track.ID: TrackPreference] = [:]
            for preference in loaded {
                guard (-Self.maximumPreference ... Self.maximumPreference)
                    .contains(preference.playbackPreference) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                guard merged.updateValue(preference, forKey: preference.trackID) == nil else {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
            for (trackID, current) in entries { merged[trackID] = current }
            entries = merged
            isLoaded = true
            if hadPendingChanges { try await persistence.save(Array(merged.values)) }
        } catch {
            errorMessage = "曲の設定を読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func isFavorite(trackID: Track.ID) -> Bool { entries[trackID]?.favorite == true }
    func playbackPreference(for trackID: Track.ID) -> Int { entries[trackID]?.playbackPreference ?? 0 }

    func toggleFavorite(trackID: Track.ID) {
        var preference = entry(for: trackID)
        preference.favorite.toggle()
        update(preference)
    }

    func increasePlaybackPreference(for trackID: Track.ID) { adjust(trackID, by: 1) }
    func decreasePlaybackPreference(for trackID: Track.ID) { adjust(trackID, by: -1) }

    func favoriteTracks(from tracks: [Track], limit: Int? = nil) -> [Track] {
        let result = tracks.filter { $0.isEligibleForRegularPlayback && isFavorite(trackID: $0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return limit.map { Array(result.prefix($0)) } ?? result
    }

    func dismissError() { errorMessage = nil }

    func importPreferences(
        _ imported: [TrackPreference],
        libraryTrackIDs: Set<Track.ID>
    ) async throws -> TrackPreferenceImportResult {
        guard isLoaded else { throw CocoaError(.fileReadUnknown) }
        await saveTask?.value

        var merged = entries
        var updated = 0
        var unchanged = 0
        var missingTrack = 0
        for preference in imported {
            guard libraryTrackIDs.contains(preference.trackID) else {
                missingTrack += 1
                continue
            }
            if merged[preference.trackID] == preference {
                unchanged += 1
            } else {
                merged[preference.trackID] = preference
                updated += 1
            }
        }

        if updated > 0 {
            try await persistence.save(Array(merged.values))
            entries = merged
        }
        return TrackPreferenceImportResult(
            total: imported.count,
            updated: updated,
            unchanged: unchanged,
            missingTrack: missingTrack,
            invalid: 0
        )
    }

    private func adjust(_ trackID: Track.ID, by value: Int) {
        var preference = entry(for: trackID)
        preference.playbackPreference = Self.clamped(preference.playbackPreference + value)
        update(preference)
    }

    private func entry(for trackID: Track.ID) -> TrackPreference {
        entries[trackID] ?? TrackPreference(trackID: trackID, playbackPreference: 0, favorite: false)
    }

    private func update(_ preference: TrackPreference) {
        entries[preference.trackID] = preference
        guard isLoaded else { return }
        let snapshot = Array(entries.values)
        let preceding = saveTask
        saveTask = Task { [weak self, persistence] in
            do {
                await preceding?.value
                try await persistence.save(snapshot)
            } catch {
                self?.errorMessage = "曲の設定を保存できませんでした: \(error.localizedDescription)"
            }
        }
    }

    private static func clamped(_ value: Int) -> Int { min(max(value, -maximumPreference), maximumPreference) }
    private static func sort(_ lhs: TrackPreference, _ rhs: TrackPreference) -> Bool {
        lhs.trackID.uuidString < rhs.trackID.uuidString
    }
}
