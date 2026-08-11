import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
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
        .alert("History Error", isPresented: historyErrorIsPresented) {
            Button("OK") { playbackHistoryStore.dismissError() }
        } message: {
            Text(playbackHistoryStore.errorMessage ?? "Playback history could not be saved.")
        }
        .task { await playlistStore.loadIfNeeded() }
        .task { await playbackHistoryStore.loadIfNeeded() }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { playerStore.errorMessage != nil },
            set: { if !$0 { playerStore.dismissError() } }
        )
    }

    private var historyErrorIsPresented: Binding<Bool> {
        Binding(
            get: { playbackHistoryStore.errorMessage != nil },
            set: { if !$0 { playbackHistoryStore.dismissError() } }
        )
    }
}
