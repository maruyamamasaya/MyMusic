import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore: PlayerStore
    @State private var playbackHistoryStore: PlaybackHistoryStore
    @State private var trackPreferenceStore: TrackPreferenceStore
    @State private var libraryStore: LibraryStore
    @State private var playlistStore = PlaylistStore()
    @State private var favoriteStore = FavoriteStore()
    @State private var settingsStore: SettingsStore
    @State private var highlightPlayerStore: HighlightPlayerStore
    @State private var trackFeatureStore: TrackFeatureStore
    @State private var trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore
    @State private var stationStore: StationStore

    init() {
        let preferenceStore = TrackPreferenceStore()
        let historyStore = PlaybackHistoryStore(preferenceStore: preferenceStore)
        let audioPlayer = AudioPlayerService()
        let featureStore = TrackFeatureStore()
        let adjustmentStore = TrackPlaybackAdjustmentStore()
        let playerStore = PlayerStore(
            audioPlayer: audioPlayer,
            playbackHistoryStore: historyStore,
            trackPlaybackAdjustmentStore: adjustmentStore,
            normalizationMetadataProvider: { trackID in
                await featureStore.loadIfNeeded()
                guard let values = featureStore.feature(for: trackID)?.values else { return nil }
                return TrackNormalizationMetadata(
                    automaticGainDB: values.normalizationGainDB,
                    truePeakDBTP: values.truePeakDBTP
                )
            }
        )
        let libraryStore = LibraryStore()
        _libraryStore = State(initialValue: libraryStore)
        _trackFeatureStore = State(initialValue: featureStore)
        _trackPlaybackAdjustmentStore = State(initialValue: adjustmentStore)
        _stationStore = State(initialValue: StationStore(
            libraryStore: libraryStore, featureStore: featureStore,
            historyStore: historyStore, playerStore: playerStore
        ))
        _playbackHistoryStore = State(initialValue: historyStore)
        _trackPreferenceStore = State(initialValue: preferenceStore)
        _playerStore = State(initialValue: playerStore)
        _highlightPlayerStore = State(initialValue: HighlightPlayerStore(
            playerStore: playerStore,
            playbackHistoryStore: historyStore,
            trackFeatureStore: featureStore
        ))
        _settingsStore = State(initialValue: SettingsStore(
            equalizerController: audioPlayer,
            playbackTransitionController: audioPlayer,
            volumeNormalizationController: audioPlayer
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(favoriteStore)
                .environment(playbackHistoryStore)
                .environment(trackPreferenceStore)
                .environment(settingsStore)
                .environment(highlightPlayerStore)
                .environment(trackFeatureStore)
                .environment(trackPlaybackAdjustmentStore)
                .environment(stationStore)
        }
    }
}
