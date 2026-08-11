import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore: PlayerStore
    @State private var playbackHistoryStore: PlaybackHistoryStore
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var settingsStore = SettingsStore()

    init() {
        let historyStore = PlaybackHistoryStore()
        _playbackHistoryStore = State(initialValue: historyStore)
        _playerStore = State(initialValue: PlayerStore(playbackHistoryStore: historyStore))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(playbackHistoryStore)
                .environment(settingsStore)
        }
    }
}
