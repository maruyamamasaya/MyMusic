import SwiftUI

struct RootView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(TrackPreferenceStore.self) private var trackPreferenceStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(FavoriteStore.self) private var favoriteStore
    @Environment(HighlightPlayerStore.self) private var highlightStore
    @Environment(TrackFeatureStore.self) private var trackFeatureStore
    @Environment(TrackPlaybackAdjustmentStore.self) private var trackPlaybackAdjustmentStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var isNowPlayingPresented = false
    @State private var returnsHomeAfterNowPlaying = false
    @State private var selectedTab = RootTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("ホーム", systemImage: "house", value: .home) {
                HomeView(
                    isActive: selectedTab == .home
                        && !isNowPlayingPresented
                        && scenePhase == .active
                )
            }
            Tab("ライブラリ", systemImage: "music.note.list", value: .library) { LibraryView() }
            Tab("プレイリスト", systemImage: "list.bullet.rectangle", value: .playlist) { PlaylistView() }
            Tab("検索", systemImage: "magnifyingglass", value: .search) { SearchView() }
            Tab("ハイライト", systemImage: "sparkles.rectangle.stack", value: .highlight) {
                HighlightPlayerView {
                    returnsHomeAfterNowPlaying = true
                    isNowPlayingPresented = true
                }
            }
        }
        .modifier(MiniPlayerAccessoryModifier(
            isPresented: playerStore.currentTrack != nil && selectedTab != .highlight
        ) {
            returnsHomeAfterNowPlaying = false
            isNowPlayingPresented = true
        })
        .animation(.default, value: playerStore.currentTrack?.id)
        .sheet(isPresented: $isNowPlayingPresented, onDismiss: handleNowPlayingDismissal) {
            Group {
                if playerStore.presentationMode == .workSize {
                    WorkSizeNowPlayingView()
                } else {
                    NowPlayingView()
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .highlight, newTab.resetsHighlightSelection {
                highlightStore.resetRandomSelection()
            }
            if newTab == .highlight {
                highlightStore.updateLibrary(libraryStore.tracks)
                highlightStore.startIfNeeded()
            }
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
        .alert("曲の設定エラー", isPresented: preferenceErrorIsPresented) {
            Button("閉じる") { trackPreferenceStore.dismissError() }
        } message: {
            Text(trackPreferenceStore.errorMessage ?? "曲の設定を保存できませんでした。")
        }
        .alert("曲別設定のエラー", isPresented: adjustmentErrorIsPresented) {
            Button("閉じる") { trackPlaybackAdjustmentStore.dismissError() }
        } message: {
            Text(trackPlaybackAdjustmentStore.errorMessage ?? "曲別の再生設定を保存できませんでした。")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                playerStore.persistPlaybackPositionForLifecycle()
                playerStore.persistPlaybackHistoryForLifecycle()
            }
        }
        .task { await playlistStore.loadIfNeeded() }
        .task {
            await playbackHistoryStore.loadIfNeeded()
            await trackPreferenceStore.loadIfNeeded(
                legacyHistory: playbackHistoryStore.errorMessage == nil
                    ? playbackHistoryStore.entries
                    : nil
            )
        }
        .task { await favoriteStore.loadIfNeeded() }
        .task { await libraryStore.restoreAndLoadIfNeeded() }
        .task { await trackFeatureStore.loadIfNeeded() }
    }

    private func handleNowPlayingDismissal() {
        guard returnsHomeAfterNowPlaying else { return }
        returnsHomeAfterNowPlaying = false
        selectedTab = .home
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

    private var preferenceErrorIsPresented: Binding<Bool> {
        Binding(
            get: { trackPreferenceStore.errorMessage != nil },
            set: { if !$0 { trackPreferenceStore.dismissError() } }
        )
    }

    private var adjustmentErrorIsPresented: Binding<Bool> {
        Binding(
            get: { trackPlaybackAdjustmentStore.errorMessage != nil },
            set: { if !$0 { trackPlaybackAdjustmentStore.dismissError() } }
        )
    }
}

private enum RootTab: Hashable {
    case home
    case library
    case playlist
    case search
    case highlight

    var resetsHighlightSelection: Bool {
        switch self {
        case .home, .library, .search:
            true
        case .playlist, .highlight:
            false
        }
    }
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
