import SwiftUI

@main
struct MyMusicApp: App {
    @State private var playerStore = PlayerStore()
    @State private var libraryStore = LibraryStore()
    @State private var playlistStore = PlaylistStore()
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerStore)
                .environment(libraryStore)
                .environment(playlistStore)
                .environment(settingsStore)
        }
    }
}
