import Foundation
import Observation

/// Ephemeral selection session. Leaving the page forgets selection, never the playing queue.
@MainActor
@Observable
final class ManualQueueStore {
    private(set) var candidates: [Track] = []
    private(set) var selectedIDs: Set<Track.ID> = []
    private var expectedQueueIDs: [Track.ID] = []

    var hasStarted: Bool { !expectedQueueIDs.isEmpty }

    func refresh(from tracks: [Track], history: PlaybackHistoryStore) {
        var seen = Set<Track.ID>()
        candidates = Array(tracks.filter {
            seen.insert($0.id).inserted && history.isEligibleForRegularShuffle($0)
        }.shuffled().prefix(30))
    }

    func select(_ track: Track, player: PlayerStore, playNext: Bool = false) {
        // Playback started elsewhere, or the queue was edited: start a fresh session.
        if player.queue.map(\.id) != expectedQueueIDs {
            resetSelection()
        }
        guard !selectedIDs.contains(track.id) else { return }
        if hasStarted {
            player.appendToManualQueue(track, playNext: playNext)
        } else {
            player.startManualQueue(with: track)
        }
        expectedQueueIDs = player.queue.map(\.id)
        selectedIDs.insert(track.id)
    }

    func upcomingTracks(player: PlayerStore) -> [Track] {
        upcomingPositions(player: player).compactMap { position in
            let index = player.playbackOrder[position]
            return player.queue.indices.contains(index) ? player.queue[index] : nil
        }
    }

    func removeUpcoming(atOffsets offsets: IndexSet, player: PlayerStore) {
        guard hasStarted, player.queue.map(\.id) == expectedQueueIDs else { return }
        let positions = upcomingPositions(player: player)
        let queueOffsets = IndexSet(offsets.compactMap {
            positions.indices.contains($0) ? positions[$0] : nil
        })
        player.removeQueueItems(atOffsets: queueOffsets)
        synchronizeSelection(player: player)
    }

    func moveUpcoming(fromOffsets source: IndexSet, toOffset destination: Int, player: PlayerStore) {
        guard hasStarted, player.queue.map(\.id) == expectedQueueIDs else { return }
        let positions = upcomingPositions(player: player)
        guard let start = positions.first else { return }
        let queueOffsets = IndexSet(source.compactMap {
            positions.indices.contains($0) ? positions[$0] : nil
        })
        player.moveQueueItems(fromOffsets: queueOffsets,
                              toOffset: start + min(max(destination, 0), positions.count))
        synchronizeSelection(player: player)
    }

    private func upcomingPositions(player: PlayerStore) -> [Int] {
        guard let current = player.currentIndex,
              let position = player.playbackOrder.firstIndex(of: current) else { return [] }
        return Array(player.playbackOrder.indices.dropFirst(position + 1))
    }

    private func synchronizeSelection(player: PlayerStore) {
        expectedQueueIDs = player.queue.map(\.id)
        selectedIDs = Set(expectedQueueIDs)
    }

    func resetSelection() {
        selectedIDs = []
        expectedQueueIDs = []
    }
}
