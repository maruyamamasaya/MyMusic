import Foundation

@MainActor
final class PlaybackHistoryCoordinator {
    private let store: PlaybackHistoryStore

    init(store: PlaybackHistoryStore) {
        self.store = store
    }

    func recordPlaybackCompleted(trackID: Track.ID) {
        store.recordPlaybackCompleted(trackID: trackID)
    }
}
