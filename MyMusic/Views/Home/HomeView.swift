import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(FavoriteStore.self) private var favoriteStore

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
                        if category.id == .myMusic {
                            if playlistStore.playlists.isEmpty || !homePlaylists.isEmpty {
                                HomePlaylistSection(
                                    playlists: Array(homePlaylists.prefix(5)),
                                    showsMore: homePlaylists.count > 5,
                                    tracksForPlaylist: { playlistStore.tracks(for: $0.id, in: libraryStore.tracks) },
                                    onPlay: playPlaylist
                                )
                            }
                            if !libraryStore.genreDisplayPresets.isEmpty {
                                HomeTuningSection(
                                    presets: Array(libraryStore.genreDisplayPresets.prefix(10)),
                                    showsMore: libraryStore.genreDisplayPresets.count > 10,
                                    isActive: libraryStore.isGenreDisplayPresetActive,
                                    onApply: libraryStore.applyGenreDisplayPreset
                                )
                            }
                        }
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

    private var homePlaylists: [Playlist] {
        let visibleTrackIDs = Set(libraryStore.tracks.map(\.id))
        return playlistStore.playlists
            .filter { playlist in
                playlist.trackIDs.contains { visibleTrackIDs.contains($0) }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func playPlaylist(_ playlist: Playlist) {
        let tracks = playlistStore.tracks(for: playlist.id, in: libraryStore.tracks)
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(true)
        playerStore.playQueue(tracks, startingAt: Int.random(in: tracks.indices))
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
        case .favoriteAlbums:
            tracks = favoriteAlbumTracks
        case .favoriteArtists:
            tracks = favoriteArtistTracks
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
        case .favoriteAlbums:
            !favoriteAlbumTracks.isEmpty
        case .favoriteArtists:
            !favoriteArtistTracks.isEmpty
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
        case .favoriteAlbums:
            tracks = favoriteAlbumTracks
        case .favoriteArtists:
            tracks = favoriteArtistTracks
        default:
            return
        }

        guard !tracks.isEmpty else { return }
        if destination == .favoriteAlbums || destination == .favoriteArtists {
            playerStore.setShuffleEnabled(false)
        }
        playerStore.playQueue(tracks, startingAt: 0)
    }

    private var favoriteAlbumTracks: [Track] {
        uniqueTracks(
            favoriteStore.favoriteAlbums(from: libraryStore.albums)
                .flatMap { libraryStore.tracks(for: $0) }
        )
    }

    private var favoriteArtistTracks: [Track] {
        uniqueTracks(
            favoriteStore.favoriteArtists(from: libraryStore.artists)
                .flatMap { libraryStore.tracks(for: $0) }
        )
    }

    private func uniqueTracks(_ tracks: [Track]) -> [Track] {
        var seen: Set<Track.ID> = []
        return tracks.filter { seen.insert($0.id).inserted }
    }
}

private struct HomeTuningSection: View {
    let presets: [GenreDisplayPreset]
    let showsMore: Bool
    let isActive: (GenreDisplayPreset) -> Bool
    let onApply: (GenreDisplayPreset) -> Void

    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let nextTilePeek: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("チューニング").font(.title3.weight(.bold))
                Text("シーンに合わせてライブラリの表示を切り替え")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, horizontalPadding)

            GeometryReader { proxy in
                let width = tileWidth(for: proxy.size.width)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        ForEach(presets) { preset in
                            Button { onApply(preset) } label: {
                                HomeTuningTile(preset: preset, isActive: isActive(preset), width: width)
                            }
                            .buttonStyle(.plain)
                        }
                        if showsMore {
                            NavigationLink(value: HomeDestination.tunings) {
                                HomeTuningMoreTile(width: width)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            }
            .frame(height: 168)
        }
    }

    private func tileWidth(for availableWidth: CGFloat) -> CGFloat {
        let visibleTileCount: CGFloat
        switch availableWidth {
        case ..<600: visibleTileCount = 2
        case ..<800: visibleTileCount = 3
        case ..<1_100: visibleTileCount = 5
        default: visibleTileCount = 6
        }
        let contentWidth = availableWidth - (horizontalPadding * 2) - nextTilePeek
        return min(180, max(132, (contentWidth - spacing * (visibleTileCount - 1)) / visibleTileCount))
    }
}

private struct HomeTuningTile: View {
    let preset: GenreDisplayPreset
    let isActive: Bool
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: isActive ? "slider.horizontal.3" : "tuningfork")
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.17), in: RoundedRectangle(cornerRadius: 12))
            Spacer()
            Text(preset.name).font(.headline).lineLimit(2)
            Text(isActive ? "適用中" : "タップして適用")
                .font(.caption).foregroundStyle(.white.opacity(0.78)).padding(.top, 3)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: width, height: 168, alignment: .leading)
        .background(tuningGradientBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 0.5) }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityLabel("チューニング、\(preset.name)")
        .accessibilityHint(isActive ? "現在適用中です" : "ライブラリの表示を切り替えます")
    }

    private var tuningGradientBackground: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: gradientStartsAtTopTrailing ? .topTrailing : .topLeading,
            endPoint: gradientStartsAtTopTrailing ? .bottomLeading : .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: gradientStartsAtTopTrailing ? .topTrailing : .topLeading,
                startRadius: 0,
                endRadius: 145
            )
        }
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.08), location: 0),
                    .init(color: .black.opacity(0.18), location: 0.48),
                    .init(color: .black.opacity(0.46), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.12, green: 0.58, blue: 0.96), Color(red: 0.20, green: 0.28, blue: 0.78), Color(red: 0.10, green: 0.08, blue: 0.30)],
            [Color(red: 0.96, green: 0.38, blue: 0.34), Color(red: 0.68, green: 0.16, blue: 0.34), Color(red: 0.27, green: 0.07, blue: 0.22)],
            [Color(red: 0.12, green: 0.72, blue: 0.61), Color(red: 0.04, green: 0.43, blue: 0.45), Color(red: 0.03, green: 0.18, blue: 0.25)],
            [Color(red: 0.96, green: 0.66, blue: 0.20), Color(red: 0.88, green: 0.31, blue: 0.18), Color(red: 0.35, green: 0.10, blue: 0.12)],
            [Color(red: 0.69, green: 0.42, blue: 0.95), Color(red: 0.37, green: 0.20, blue: 0.66), Color(red: 0.13, green: 0.08, blue: 0.28)]
        ]
        return palettes[paletteIndex]
    }

    private var paletteIndex: Int {
        preset.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 5 }
    }

    private var gradientStartsAtTopTrailing: Bool {
        paletteIndex.isMultiple(of: 2)
    }
}

private struct HomeTuningMoreTile: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "arrow.right.circle.fill").font(.largeTitle)
            Spacer()
            Text("続きを見る").font(.headline)
            Text("すべてのシーン").font(.caption).foregroundStyle(.white.opacity(0.76)).padding(.top, 3)
        }
        .foregroundStyle(.white).padding(14)
        .frame(width: width, height: 168, alignment: .leading)
        .background(LinearGradient(colors: [.indigo, .black.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct HomePlaylistSection: View {
    let playlists: [Playlist]
    let showsMore: Bool
    let tracksForPlaylist: (Playlist) -> [Track]
    let onPlay: (Playlist) -> Void

    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let nextTilePeek: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("プレイリスト")
                    .font(.title3.weight(.bold))
                Text("最近作成したプレイリストをランダム再生")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, horizontalPadding)

            GeometryReader { proxy in
                let tileWidth = tileWidth(for: proxy.size.width)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        if playlists.isEmpty {
                            NavigationLink(value: HomeDestination.playlists) {
                                HomePlaylistEmptyTile(width: tileWidth)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(playlists) { playlist in
                                let tracks = tracksForPlaylist(playlist)
                                Button { onPlay(playlist) } label: {
                                    HomePlaylistTile(
                                        playlist: playlist,
                                        artworkIdentifiers: playlistArtworkIdentifiers(playlist: playlist, tracks: tracks),
                                        trackCount: tracks.count,
                                        width: tileWidth
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(tracks.isEmpty)
                                .opacity(tracks.isEmpty ? 0.55 : 1)
                            }

                            if showsMore {
                                NavigationLink(value: HomeDestination.playlists) {
                                    HomePlaylistMoreTile(width: tileWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            }
            .frame(height: 168)
        }
    }

    private func playlistArtworkIdentifiers(playlist: Playlist, tracks: [Track]) -> [String] {
        var identifiers = tracks.compactMap(\.artworkIdentifier)
        if let artworkIdentifier = playlist.artworkIdentifier {
            identifiers.insert(artworkIdentifier, at: 0)
        }
        return Array(Set(identifiers))
    }

    private func tileWidth(for availableWidth: CGFloat) -> CGFloat {
        let visibleTileCount: CGFloat
        switch availableWidth {
        case ..<600: visibleTileCount = 2
        case ..<800: visibleTileCount = 3
        case ..<1_100: visibleTileCount = 5
        default: visibleTileCount = 6
        }
        let contentWidth = availableWidth - (horizontalPadding * 2) - nextTilePeek
        return min(180, max(132, (contentWidth - spacing * (visibleTileCount - 1)) / visibleTileCount))
    }
}

private struct HomePlaylistTile: View {
    let playlist: Playlist
    let artworkIdentifiers: [String]
    let trackCount: Int
    let width: CGFloat
    @State private var selectedArtworkIdentifier: String?

    var body: some View {
        ZStack(alignment: .leading) {
            if let selectedArtworkIdentifier {
                HomeTileArtworkBackground(artworkIdentifier: selectedArtworkIdentifier)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.29, blue: 0.40), Color(red: 0.08, green: 0.09, blue: 0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.20), location: 0),
                    .init(color: .black.opacity(0.38), location: 0.48),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "music.note.list")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)
                Text("\(trackCount)曲")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.top, 3)
            }
            .foregroundStyle(.white)
            .padding(14)
        }
        .frame(width: width, height: 168, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 0.5) }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityHint("プレイリストをランダム再生")
        .task(id: artworkIdentifiers) {
            selectedArtworkIdentifier = artworkIdentifiers.randomElement()
        }
    }
}

private struct HomePlaylistMoreTile: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.largeTitle)
            Spacer()
            Text("続きを見る")
                .font(.headline)
            Text("すべてのプレイリスト")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.76))
                .padding(.top, 3)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: width, height: 168, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.30, green: 0.24, blue: 0.62), Color(red: 0.08, green: 0.10, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct HomePlaylistEmptyTile: View {
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "plus.circle.fill").font(.largeTitle)
            Spacer()
            Text("プレイリストを作成").font(.headline).lineLimit(2)
            Text("曲をまとめて楽しむ").font(.caption).foregroundStyle(.white.opacity(0.76)).padding(.top, 3)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: width, height: 168, alignment: .leading)
        .background(LinearGradient(colors: [Color.indigo, Color.black.opacity(0.84)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
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
        case .quickPlay, .discoveryPlay, .repeatPlay, .favorites, .favoriteAlbums, .favoriteArtists:
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

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(contentColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(contentColor.opacity(0.78))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                }
                .frame(height: 71, alignment: .topLeading)
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
        } else if categoryID == .library || categoryID == .activity {
            decorativeGradientBackground
        } else {
            RoundedRectangle(cornerRadius: 18).fill(.background.secondary)
        }
    }

    private var decorativeGradientBackground: some View {
        LinearGradient(
            colors: decorativeColors,
            startPoint: gradientStartsAtTopTrailing ? .topTrailing : .topLeading,
            endPoint: gradientStartsAtTopTrailing ? .bottomLeading : .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: gradientStartsAtTopTrailing ? .topTrailing : .topLeading,
                startRadius: 0,
                endRadius: 145
            )
        }
        .overlay(decorativeReadabilityMask)
    }

    private var decorativeColors: [Color] {
        switch item.destination {
        case .songs:
            // Electric blue settling into a deep indigo.
            [
                Color(red: 0.12, green: 0.58, blue: 0.96),
                Color(red: 0.20, green: 0.28, blue: 0.78),
                Color(red: 0.10, green: 0.08, blue: 0.30)
            ]
        case .albums:
            // Warm coral and wine, kept darker than a social-media gradient.
            [
                Color(red: 0.96, green: 0.38, blue: 0.34),
                Color(red: 0.68, green: 0.16, blue: 0.34),
                Color(red: 0.27, green: 0.07, blue: 0.22)
            ]
        case .artists:
            [
                Color(red: 0.12, green: 0.72, blue: 0.61),
                Color(red: 0.04, green: 0.43, blue: 0.45),
                Color(red: 0.03, green: 0.18, blue: 0.25)
            ]
        case .genres:
            [
                Color(red: 0.96, green: 0.66, blue: 0.20),
                Color(red: 0.88, green: 0.31, blue: 0.18),
                Color(red: 0.35, green: 0.10, blue: 0.12)
            ]
        case .composers:
            [
                Color(red: 0.69, green: 0.42, blue: 0.95),
                Color(red: 0.37, green: 0.20, blue: 0.66),
                Color(red: 0.13, green: 0.08, blue: 0.28)
            ]
        case .analytics:
            [
                Color(red: 0.18, green: 0.78, blue: 0.88),
                Color(red: 0.08, green: 0.42, blue: 0.68),
                Color(red: 0.16, green: 0.12, blue: 0.38)
            ]
        default:
            [Color.accentColor, Color.accentColor.opacity(0.65), Color.black.opacity(0.72)]
        }
    }

    private var gradientStartsAtTopTrailing: Bool {
        switch item.destination {
        case .albums, .genres, .analytics: true
        default: false
        }
    }

    private var decorativeReadabilityMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.08), location: 0),
                .init(color: .black.opacity(0.18), location: 0.48),
                .init(color: .black.opacity(0.46), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
