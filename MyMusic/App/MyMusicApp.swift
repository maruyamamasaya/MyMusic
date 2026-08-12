import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore: PlayerStore
    @State private var playbackHistoryStore: PlaybackHistoryStore
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var favoriteStore = FavoriteStore()
    @State private var settingsStore: SettingsStore

    init() {
        let historyStore = PlaybackHistoryStore()
        let audioPlayer = AudioPlayerService()
        _playbackHistoryStore = State(initialValue: historyStore)
        _playerStore = State(initialValue: PlayerStore(audioPlayer: audioPlayer, playbackHistoryStore: historyStore))
        _settingsStore = State(initialValue: SettingsStore(equalizerController: audioPlayer))
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
        }
    }
}
