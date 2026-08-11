import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var isNowPlayingPresented = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeView() }
            Tab("Library", systemImage: "music.note.list") { LibraryView() }
            Tab("Playlists", systemImage: "list.bullet.rectangle") { PlaylistView() }
            Tab("Search", systemImage: "magnifyingglass") { SearchView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if playerStore.currentTrack != nil {
                MiniPlayerView {
                    isNowPlayingPresented = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: playerStore.currentTrack?.id)
        .sheet(isPresented: $isNowPlayingPresented) {
            NowPlayingView()
                .presentationDragIndicator(.visible)
        }
        .alert("Playback Error", isPresented: errorIsPresented) {
            Button("OK") { playerStore.dismissError() }
        } message: {
            Text(playerStore.errorMessage ?? "Playback failed.")
        }
        .task { await playlistStore.loadIfNeeded() }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { playerStore.errorMessage != nil },
            set: { if !$0 { playerStore.dismissError() } }
        )
    }
}
