import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore: PlayerStore
    @State private var playbackHistoryStore: PlaybackHistoryStore
    @State private var libraryStore: LibraryStore
    @State private var playlistStore = PlaylistStore()
    @State private var favoriteStore = FavoriteStore()
    @State private var settingsStore: SettingsStore
    @State private var highlightPlayerStore: HighlightPlayerStore
    @State private var trackFeatureStore: TrackFeatureStore
    @State private var stationStore: StationStore

    init() {
        let historyStore = PlaybackHistoryStore()
        let audioPlayer = AudioPlayerService()
        let playerStore = PlayerStore(audioPlayer: audioPlayer, playbackHistoryStore: historyStore)
        let libraryStore = LibraryStore()
        let featureStore = TrackFeatureStore()
        _libraryStore = State(initialValue: libraryStore)
        _trackFeatureStore = State(initialValue: featureStore)
        _stationStore = State(initialValue: StationStore(
            libraryStore: libraryStore, featureStore: featureStore,
            historyStore: historyStore, playerStore: playerStore
        ))
        _playbackHistoryStore = State(initialValue: historyStore)
        _playerStore = State(initialValue: playerStore)
        _highlightPlayerStore = State(initialValue: HighlightPlayerStore(playerStore: playerStore))
        _settingsStore = State(initialValue: SettingsStore(
            equalizerController: audioPlayer,
            playbackTransitionController: audioPlayer
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
                .environment(settingsStore)
                .environment(highlightPlayerStore)
                .environment(trackFeatureStore)
                .environment(stationStore)
        }
    }
}
