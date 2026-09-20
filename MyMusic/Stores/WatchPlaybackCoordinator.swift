import Foundation

/// Connects Watch messages to the iPhone's existing playback and preference owners.
@MainActor
final class WatchPlaybackCoordinator {
    private let service: WatchConnectivityServicing
    private let preferenceStore: TrackPreferenceStore
    private weak var libraryStore: LibraryStore?
    private let playbackCommand: (WatchPlaybackCommand) -> Void
    private let shuffleCommand: (WatchShuffleKind, [Track], TrackPreferenceStore) async -> String?
    private var playbackState = WatchPlaybackState.empty

    init(
        service: WatchConnectivityServicing,
        preferenceStore: TrackPreferenceStore,
        libraryStore: LibraryStore,
        playbackCommand: @escaping (WatchPlaybackCommand) -> Void,
        shuffleCommand: @escaping (WatchShuffleKind, [Track], TrackPreferenceStore) async -> String?
    ) {
        self.service = service
        self.preferenceStore = preferenceStore
        self.libraryStore = libraryStore
        self.playbackCommand = playbackCommand
        self.shuffleCommand = shuffleCommand

        service.commandHandler = { [weak self] command in self?.handle(command) }
        service.shuffleHandler = { [weak self] kind in
            guard let self, let libraryStore = self.libraryStore else {
                return "iPhoneでMyMusicを開いてください"
            }
            return await self.shuffleCommand(kind, libraryStore.tracks, self.preferenceStore)
        }
        service.stateProvider = { [weak self] in self?.playbackState ?? .empty }
        preferenceStore.stateChangeHandler = { [weak self] in self?.publishState() }
        service.activate()
    }

    func updateState(track: Track?, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        playbackState = WatchPlaybackState(
            trackID: track?.id,
            title: track?.title ?? "",
            artist: track?.artistName ?? "",
            album: track?.albumTitle ?? "",
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            isFavorite: track.map { preferenceStore.isFavorite(trackID: $0.id) } ?? false,
            playbackPreference: track.map { preferenceStore.playbackPreference(for: $0.id) } ?? 0,
            hasArtwork: track?.artworkIdentifier != nil,
            artworkIdentifier: track?.artworkIdentifier
        )
        publishState()
    }

    private func publishState() {
        // Preference changes must use the latest value even when playback has not changed.
        if let trackID = playbackState.trackID {
            playbackState.isFavorite = preferenceStore.isFavorite(trackID: trackID)
            playbackState.playbackPreference = preferenceStore.playbackPreference(for: trackID)
        }
        service.publish(playbackState, artworkIdentifier: playbackState.artworkIdentifier)
    }

    private func handle(_ command: WatchPlaybackCommand) {
        switch command {
        case .play, .pause, .togglePlayPause, .next, .previous:
            playbackCommand(command)
        case .toggleFavorite:
            if let trackID = playbackState.trackID { preferenceStore.toggleFavorite(trackID: trackID) }
        case .increasePlaybackPreference:
            if let trackID = playbackState.trackID { preferenceStore.increasePlaybackPreference(for: trackID) }
        case .decreasePlaybackPreference:
            if let trackID = playbackState.trackID { preferenceStore.decreasePlaybackPreference(for: trackID) }
        case .requestArtwork, .requestState:
            break
        }
    }
}
