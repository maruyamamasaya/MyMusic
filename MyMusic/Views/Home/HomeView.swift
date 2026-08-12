import SwiftUI

struct HomeView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var presentedPlaybackDestination: HomeDestination?

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(HomeCategory.all) { category in
                        HomeCarouselSection(
                            category: category,
                            playbackIsAvailable: playerStore.currentTrack != nil,
                            onPresentPlayback: { presentedPlaybackDestination = $0 }
                        )
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("ホーム")
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
}

private struct HomeCarouselSection: View {
    let category: HomeCategory
    let playbackIsAvailable: Bool
    let onPresentPlayback: (HomeDestination) -> Void

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
        if isPlaybackDestination(item.destination) {
            Button {
                onPresentPlayback(item.destination)
            } label: {
                HomeItemTile(item: item, width: width)
            }
            .buttonStyle(.plain)
            .disabled(!playbackIsAvailable)
            .opacity(playbackIsAvailable ? 1 : 0.55)
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

    private func isPlaybackDestination(_ destination: HomeDestination) -> Bool {
        destination == .nowPlaying || destination == .queue
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
