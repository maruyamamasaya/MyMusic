import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(HomeCategory.all) { category in
                        HomeCarouselSection(
                            category: category,
                            instantPlaybackIsAvailable: instantPlaybackIsAvailable,
                            onInstantPlay: playImmediately
                        )
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("ホーム")
            .navigationDestination(for: HomeDestination.self) { destination in
                HomeDestinationView(destination: destination)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
            }
        }
    }

    private func instantPlaybackIsAvailable(_ destination: HomeDestination) -> Bool {
        switch destination {
        case .quickPlay:
            !libraryStore.tracks.isEmpty
        case .discoveryPlay:
            libraryStore.tracks.contains { playbackHistoryStore.playCount(for: $0.id) == 0 }
        case .repeatPlay:
            !playbackHistoryStore.repeatPlayTracks(from: libraryStore.tracks, limit: 1).isEmpty
        case .favorites:
            !playbackHistoryStore.favoriteTracks(from: libraryStore.tracks, limit: 1).isEmpty
        default:
            true
        }
    }

    private func playImmediately(_ destination: HomeDestination) {
        let tracks: [Track]
        switch destination {
        case .quickPlay:
            tracks = playbackHistoryStore.quickPlayTracks(from: libraryStore.tracks)
        case .discoveryPlay:
            tracks = playbackHistoryStore.discoveryPlayTracks(from: libraryStore.tracks)
        case .repeatPlay:
            tracks = playbackHistoryStore.repeatPlayTracks(from: libraryStore.tracks)
        case .favorites:
            tracks = playbackHistoryStore.favoriteTracks(from: libraryStore.tracks).shuffled()
        default:
            return
        }

        guard !tracks.isEmpty else { return }
        playerStore.playQueue(tracks, startingAt: 0)
    }
}

private struct HomeCarouselSection: View {
    let category: HomeCategory
    let instantPlaybackIsAvailable: (HomeDestination) -> Bool
    let onInstantPlay: (HomeDestination) -> Void

    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let nextTilePeek: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.title3.weight(.bold))
                Text(category.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, horizontalPadding)

            GeometryReader { proxy in
                let tileWidth = tileWidth(for: proxy.size.width)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        ForEach(category.items) { item in
                            tile(for: item, width: tileWidth)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            }
            .frame(height: tileHeight)
        }
    }

    @ViewBuilder
    private func tile(for item: HomeCategoryItem, width: CGFloat) -> some View {
        if isInstantPlaybackDestination(item.destination) {
            Button {
                onInstantPlay(item.destination)
            } label: {
                HomeItemTile(item: item, width: width)
            }
            .buttonStyle(.plain)
            .disabled(!instantPlaybackIsAvailable(item.destination))
            .opacity(instantPlaybackIsAvailable(item.destination) ? 1 : 0.55)
        } else {
            NavigationLink(value: item.destination) {
                HomeItemTile(item: item, width: width)
            }
            .buttonStyle(.plain)
        }
    }

    private var tileHeight: CGFloat { 168 }

    private func tileWidth(for availableWidth: CGFloat) -> CGFloat {
        let visibleTileCount: CGFloat
        switch availableWidth {
        case ..<600:
            visibleTileCount = 2
        case ..<800:
            visibleTileCount = 3
        case ..<1_100:
            visibleTileCount = 5
        default:
            visibleTileCount = 6
        }

        let contentWidth = availableWidth - (horizontalPadding * 2) - nextTilePeek
        let interItemSpacing = spacing * (visibleTileCount - 1)
        return min(180, max(132, (contentWidth - interItemSpacing) / visibleTileCount))
    }

    private func isInstantPlaybackDestination(_ destination: HomeDestination) -> Bool {
        switch destination {
        case .quickPlay, .discoveryPlay, .repeatPlay, .favorites:
            true
        default:
            false
        }
    }
}

private struct HomeItemTile: View {
    let item: HomeCategoryItem
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: item.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 46, height: 46)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

            Spacer(minLength: 10)

            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 3)
        }
        .padding(14)
        .frame(width: width, height: 168, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.separator.opacity(0.35), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
