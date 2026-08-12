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
                            artworkIdentifiers: artworkIdentifiers,
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

    private func artworkIdentifiers(for destination: HomeDestination) -> [String] {
        let tracks: [Track]
        switch destination {
        case .quickPlay:
            tracks = libraryStore.tracks
        case .discoveryPlay:
            tracks = libraryStore.tracks.filter { playbackHistoryStore.playCount(for: $0.id) == 0 }
        case .repeatPlay:
            tracks = libraryStore.tracks.filter { playbackHistoryStore.playCount(for: $0.id) >= 2 }
        case .favorites:
            tracks = playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
        case .recentTracks:
            tracks = playbackHistoryStore.recentTracks(from: libraryStore.tracks)
        default:
            return []
        }
        return Array(Set(tracks.compactMap(\.artworkIdentifier)))
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
            tracks = playbackHistoryStore.preferenceWeightedShuffle(
                playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
            )
        default:
            return
        }

        guard !tracks.isEmpty else { return }
        playerStore.playQueue(tracks, startingAt: 0)
    }
}

private struct HomeCarouselSection: View {
    let category: HomeCategory
    let artworkIdentifiers: (HomeDestination) -> [String]
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
                HomeItemTile(
                    item: item,
                    categoryID: category.id,
                    artworkIdentifiers: artworkIdentifiers(item.destination),
                    width: width
                )
            }
            .buttonStyle(.plain)
            .disabled(!instantPlaybackIsAvailable(item.destination))
            .opacity(instantPlaybackIsAvailable(item.destination) ? 1 : 0.55)
        } else {
            NavigationLink(value: item.destination) {
                HomeItemTile(
                    item: item,
                    categoryID: category.id,
                    artworkIdentifiers: artworkIdentifiers(item.destination),
                    width: width
                )
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
    @Environment(\.colorScheme) private var colorScheme

    let item: HomeCategoryItem
    let categoryID: HomeCategory.ID
    let artworkIdentifiers: [String]
    let width: CGFloat
    @State private var selectedArtworkIdentifier: String?

    var body: some View {
        ZStack {
            tileBackground

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: item.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(contentColor)
                    .frame(width: 46, height: 46)
                    .background(contentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))

                Spacer(minLength: 10)

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(contentColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(contentColor.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)
            }
            .padding(14)
        }
        .frame(width: width, height: 168, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.separator.opacity(0.35), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .task(id: artworkIdentifiers) { selectRandomArtwork() }
    }

    @ViewBuilder
    private var tileBackground: some View {
        if let selectedArtworkIdentifier {
            HomeTileArtworkBackground(artworkIdentifier: selectedArtworkIdentifier)
                .opacity(colorScheme == .dark ? 0.68 : 0.58)
                .overlay(readabilityMask)
        } else if categoryID == .library {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.24, blue: 0.46), .orange, Color(red: 0.55, green: 0.16, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.black.opacity(0.12))
        } else if categoryID == .activity {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.92, blue: 0.86), Color(red: 0.18, green: 0.12, blue: 0.28), Color(red: 1, green: 0.10, blue: 0.48)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.black.opacity(0.16))
        } else {
            RoundedRectangle(cornerRadius: 18).fill(.background.secondary)
        }
    }

    private var readabilityMask: LinearGradient {
        let maskColor = colorScheme == .dark ? Color.black : Color.white
        return LinearGradient(
            stops: [
                .init(color: maskColor.opacity(colorScheme == .dark ? 0.32 : 0.25), location: 0),
                .init(color: maskColor.opacity(colorScheme == .dark ? 0.62 : 0.70), location: 0.48),
                .init(color: maskColor.opacity(colorScheme == .dark ? 0.91 : 0.94), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var contentColor: Color {
        if selectedArtworkIdentifier != nil {
            return colorScheme == .dark ? .white : .black
        }
        if categoryID == .library || categoryID == .activity { return .white }
        return .primary
    }

    private func selectRandomArtwork() {
        guard !artworkIdentifiers.isEmpty else {
            selectedArtworkIdentifier = nil
            return
        }
        selectedArtworkIdentifier = artworkIdentifiers.randomElement()
    }
}

private struct HomeTileArtworkBackground: View {
    let artworkIdentifier: String
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.18)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: artworkIdentifier) {
            image = nil
            guard let data = await ArtworkService.shared.artworkData(for: artworkIdentifier) else { return }
            image = UIImage(data: data)
        }
    }
}
