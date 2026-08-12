import SwiftUI

struct HomeCategoryDetailView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var presentedPlaybackDestination: HomeDestination?

    let category: HomeCategory

    var body: some View {
        List(category.items) { item in
            if isPlaybackDestination(item.destination) {
                Button {
                    presentedPlaybackDestination = item.destination
                } label: {
                    itemRow(item)
                }
                .buttonStyle(.plain)
                .disabled(playerStore.currentTrack == nil)
            } else {
                NavigationLink(value: item.destination) {
                    itemRow(item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: HomeDestination.self) { destination in
            HomeDestinationView(destination: destination)
        }
        .sheet(item: $presentedPlaybackDestination) { destination in
            switch destination {
            case .nowPlaying:
                NowPlayingView()
            case .queue:
                QueueView()
            default:
                EmptyView()
            }
        }
    }

    private func itemRow(_ item: HomeCategoryItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func isPlaybackDestination(_ destination: HomeDestination) -> Bool {
        destination == .nowPlaying || destination == .queue
    }
}

struct HomeDestinationView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    let destination: HomeDestination

    @ViewBuilder
    var body: some View {
        switch destination {
        case .quickPlay:
            QuickPlayView(tracks: playbackHistoryStore.quickPlayTracks(from: libraryStore.tracks))
        case .discoveryPlay:
            GeneratedQueueView(
                title: "未発見再生",
                emptyTitle: "未再生の曲はありません",
                emptyDescription: "ライブラリ内のすべての曲が再生済みです。",
                systemImage: "sparkles",
                tracks: playbackHistoryStore.discoveryPlayTracks(from: libraryStore.tracks)
            )
        case .repeatPlay:
            GeneratedQueueView(
                title: "リピート曲再生",
                emptyTitle: "対象の曲はありません",
                emptyDescription: "2回以上再生した曲がここに表示されます。",
                systemImage: "repeat",
                tracks: playbackHistoryStore.repeatPlayTracks(from: libraryStore.tracks)
            )
        case .favorites:
            FavoritesView()
        case .recentTracks:
            HomeTrackListView(
                title: "最近再生した曲",
                emptyTitle: "再生履歴はありません",
                emptyDescription: "曲を再生すると、ここに表示されます。",
                tracks: playbackHistoryStore.recentTracks(from: libraryStore.tracks)
            )
        case .playlists:
            // HomeView already owns the NavigationStack. Nesting another stack here
            // can leave navigation gestures intercepting every touch after a push.
            PlaylistView(createsNavigationStack: false)
        case .songs:
            SongsView(tracks: libraryStore.tracks)
        case .albums:
            AlbumsView(albums: libraryStore.albums)
        case .artists:
            ArtistsView(artists: libraryStore.artists)
        case .genres:
            GenresView(genres: libraryStore.genres)
        case .composers:
            ComposersView(composers: libraryStore.composers)
        case .analytics:
            AnalyticsView()
        case .nowPlaying, .queue:
            EmptyView()
        }
    }
}

private struct QuickPlayView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    let tracks: [Track]

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "再生できる曲がありません",
                    systemImage: "play.circle",
                    description: Text("ライブラリに曲を追加すると、キューが作成されます。")
                )
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: 8) {
                        Button {
                            playerStore.playQueue(tracks, startingAt: index)
                        } label: {
                            TrackRowView(track: track)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        PlaybackPreferenceButton(track: track, direction: .decrease, compact: true)
                        PlaybackPreferenceButton(track: track, direction: .increase, compact: true)
                    }
                }
            }
        }
        .navigationTitle("クイック再生")
    }

}

private struct HomeTrackListView: View {
    @Environment(PlayerStore.self) private var playerStore

    let title: String
    let emptyTitle: String
    let emptyDescription: String
    let tracks: [Track]

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "clock",
                    description: Text(emptyDescription)
                )
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    PlayableTrackRowView(track: track) {
                        playerStore.playQueue(tracks, startingAt: index)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

private struct GeneratedQueueView: View {
    @Environment(PlayerStore.self) private var playerStore

    let title: String
    let emptyTitle: String
    let emptyDescription: String
    let systemImage: String
    let tracks: [Track]

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: systemImage,
                    description: Text(emptyDescription)
                )
            } else {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    PlayableTrackRowView(track: track) {
                        playerStore.playQueue(tracks, startingAt: index)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

extension HomeDestination: Identifiable {
    var id: Self { self }
}
