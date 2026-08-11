import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var isNowPlayingPresented = false

    var body: some View {
        TabView {
            Tab("ホーム", systemImage: "house") { HomeView() }
            Tab("ライブラリ", systemImage: "music.note.list") { LibraryView() }
            Tab("プレイリスト", systemImage: "list.bullet.rectangle") { PlaylistView() }
            Tab("検索", systemImage: "magnifyingglass") { SearchView() }
        }
        .tabViewBottomAccessory {
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
        .alert("再生エラー", isPresented: errorIsPresented) {
            Button("閉じる") { playerStore.dismissError() }
        } message: {
            Text(playerStore.errorMessage ?? "再生できませんでした。")
        }
        .alert("再生履歴のエラー", isPresented: historyErrorIsPresented) {
            Button("閉じる") { playbackHistoryStore.dismissError() }
        } message: {
            Text(playbackHistoryStore.errorMessage ?? "再生履歴を保存できませんでした。")
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
