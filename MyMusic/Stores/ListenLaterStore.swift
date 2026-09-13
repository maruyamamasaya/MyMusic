import Foundation
import Observation

@MainActor
@Observable
final class ListenLaterStore {
    private(set) var entries: [ListenLaterEntry] = []
    private(set) var homePresentationRevision = 0
    private(set) var isLoaded = false
    private(set) var errorMessage: String?

    private let persistence: ListenLaterPersistenceServicing
    private var saveTask: Task<Void, Never>?
    private var isLoading = false

    init(persistence: ListenLaterPersistenceServicing? = nil) {
        self.persistence = persistence ?? ListenLaterPersistenceService()
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
            let currentTrackIDs = Set(entries.map(\.trackID))
            entries = loaded.filter { !currentTrackIDs.contains($0.trackID) } + entries
            entries = uniqueEntries(entries)
            homePresentationRevision &+= 1
        } catch {
            errorMessage = "あとで聴くリストを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func contains(_ trackID: Track.ID) -> Bool {
        entries.contains { $0.trackID == trackID }
    }

    func add(trackID: Track.ID, currentPlayCount: Int, now: Date = Date()) {
        guard !contains(trackID) else { return }
        entries.append(ListenLaterEntry(
            trackID: trackID,
            playCountWhenAdded: currentPlayCount,
            addedAt: now
        ))
        didChange()
    }

    func remove(_ trackID: Track.ID) {
        let previousCount = entries.count
        entries.removeAll { $0.trackID == trackID }
        guard entries.count != previousCount else { return }
        didChange()
    }

    func toggle(trackID: Track.ID, currentPlayCount: Int) {
        if contains(trackID) {
            remove(trackID)
        } else {
            add(trackID: trackID, currentPlayCount: currentPlayCount)
        }
    }

    func reconcile(playCounts: [Track.ID: Int]) {
        let previousCount = entries.count
        entries.removeAll { entry in
            (playCounts[entry.trackID] ?? 0) > entry.playCountWhenAdded
        }
        guard entries.count != previousCount else { return }
        didChange()
    }

    func tracks(in libraryTracks: [Track]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryTracks.map { ($0.id, $0) })
        return entries.compactMap { tracksByID[$0.trackID] }
    }

    func dismissError() { errorMessage = nil }

    func waitForPendingSave() async {
        await saveTask?.value
    }

    private func didChange() {
        homePresentationRevision &+= 1
        persist()
    }

    private func persist() {
        let snapshot = entries
        let precedingSave = saveTask
        saveTask = Task { [weak self, persistence] in
            await precedingSave?.value
            do {
                try await persistence.save(snapshot)
            } catch {
                self?.errorMessage = "あとで聴くリストを保存できませんでした: \(error.localizedDescription)"
            }
        }
    }

    private func uniqueEntries(_ entries: [ListenLaterEntry]) -> [ListenLaterEntry] {
        var seen: Set<Track.ID> = []
        return entries.filter { seen.insert($0.trackID).inserted }
    }
}
