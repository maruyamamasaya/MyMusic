import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeView() }
            Tab("Library", systemImage: "music.note.list") { LibraryView() }
            Tab("Playlists", systemImage: "list.bullet.rectangle") { PlaylistView() }
            Tab("Search", systemImage: "magnifyingglass") { SearchView() }
        }
        // A bottom safe-area inset can host MiniPlayerView when playback is enabled.
    }
}
