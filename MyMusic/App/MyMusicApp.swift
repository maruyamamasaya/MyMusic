import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore: PlayerStore
    @State private var playbackHistoryStore: PlaybackHistoryStore
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var favoriteStore = FavoriteStore()
    @State private var settingsStore: SettingsStore
    @State private var highlightPlayerStore: HighlightPlayerStore

    init() {
        let historyStore = PlaybackHistoryStore()
        let audioPlayer = AudioPlayerService()
        let playerStore = PlayerStore(audioPlayer: audioPlayer, playbackHistoryStore: historyStore)
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
        }
    }
}
