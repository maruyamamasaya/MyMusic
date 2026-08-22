import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(FavoriteStore.self) private var favoriteStore
    @State private var isNowPlayingPresented = false
    @State private var selectedTab = RootTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("ホーム", systemImage: "house", value: .home) { HomeView() }
            Tab("ライブラリ", systemImage: "music.note.list", value: .library) { LibraryView() }
            Tab("プレイリスト", systemImage: "list.bullet.rectangle", value: .playlist) { PlaylistView() }
            Tab("検索", systemImage: "magnifyingglass", value: .search) { SearchView() }
            Tab("ハイライト", systemImage: "sparkles.rectangle.stack", value: .highlight) {
                HighlightPlayerView { isNowPlayingPresented = true }
            }
        }
        .modifier(MiniPlayerAccessoryModifier(
            isPresented: playerStore.currentTrack != nil && selectedTab != .highlight
        ) {
            isNowPlayingPresented = true
        })
        .animation(.default, value: playerStore.currentTrack?.id)
        .sheet(isPresented: $isNowPlayingPresented) {
            Group {
                if playerStore.presentationMode == .workSize {
                    WorkSizeNowPlayingView()
                } else {
                    NowPlayingView()
                }
            }
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
        .alert("お気に入りのエラー", isPresented: favoriteErrorIsPresented) {
            Button("閉じる") { favoriteStore.dismissError() }
        } message: {
            Text(favoriteStore.errorMessage ?? "お気に入りを保存できませんでした。")
        }
        .task { await playlistStore.loadIfNeeded() }
        .task { await playbackHistoryStore.loadIfNeeded() }
        .task { await favoriteStore.loadIfNeeded() }
        .task { await libraryStore.restoreAndLoadIfNeeded() }
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

    private var favoriteErrorIsPresented: Binding<Bool> {
        Binding(
            get: { favoriteStore.errorMessage != nil },
            set: { if !$0 { favoriteStore.dismissError() } }
        )
    }
}

private enum RootTab: Hashable {
    case home
    case library
    case playlist
    case search
    case highlight
}

private struct MiniPlayerAccessoryModifier: ViewModifier {
    let isPresented: Bool
    let onOpen: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPresented {
            content.tabViewBottomAccessory {
                MiniPlayerView(onOpen: onOpen)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        } else {
            content
        }
    }
}
