import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(FavoriteStore.self) private var favoriteStore
    @State private var randomizedPlaylistIDs: [Playlist.ID] = []
    @State private var randomizedFavoriteAlbumIDs: [Album.ID] = []
    @State private var randomizedFavoriteArtistIDs: [Artist.ID] = []

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(HomeCategory.all.filter { $0.id != .playback }) { category in
                        HomeCarouselSection(
                            category: category,
                            artworkIdentifiers: artworkIdentifiers,
                            instantPlaybackIsAvailable: instantPlaybackIsAvailable,
                            favoriteAlbums: homeFavoriteAlbums,
                            favoriteArtists: homeFavoriteArtists,
                            artworkIdentifiersForArtist: artistArtworkIdentifiers,
                            albumsForArtist: libraryStore.albums(for:),
                            onInstantPlay: playImmediately
                        )
                        if category.id == .myMusic {
                            if !homePlaylists.isEmpty {
                                HomePlaylistSection(
                                    playlists: Array(homePlaylists.prefix(5)),
                                    showsMore: homePlaylists.count > 5,
                                    tracksForPlaylist: { playlistStore.tracks(for: $0.id, in: libraryStore.tracks) },
                                    canPlay: { playlist in
                                        playlistStore.tracks(for: playlist.id, in: libraryStore.tracks)
                                            .contains(where: playbackHistoryStore.isEligibleForRegularShuffle)
                                    },
                                    onPlay: playPlaylist
                                )
                            }
                            if let workCategory = HomeCategory.all.first(where: { $0.id == .playback }) {
                                HomeWorkSection(
                                    category: workCategory,
                                    playlists: Array(homeWorkPlaylists.prefix(4)),
                                    showsMore: homeWorkPlaylists.count > 4,
                                    artworkIdentifiers: artworkIdentifiers,
                                    instantPlaybackIsAvailable: instantPlaybackIsAvailable,
                                    tracksForPlaylist: {
                                        playlistStore.tracks(for: $0.id, in: libraryStore.tracks)
                                    },
                                    canPlay: { playlist in
                                        !playbackHistoryStore.workPlaybackTracks(
                                            from: playlistStore.tracks(
                                                for: playlist.id,
                                                in: libraryStore.tracks
                                            )
                                        ).isEmpty
                                    },
                                    onInstantPlay: playImmediately,
                                    onPlayPlaylist: playPlaylist
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
            .task(id: playlistStore.playlists.map(\.id)) {
                randomizedPlaylistIDs = playlistStore.playlists.map(\.id).shuffled()
            }
            .task(id: favoriteStore.favoriteAlbums(from: libraryStore.albums).map(\.id)) {
                randomizeFavoriteAlbums()
            }
            .task(id: favoriteStore.favoriteArtists(from: libraryStore.artists).map(\.id)) {
                randomizeFavoriteArtists()
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
        let playablePlaylists = playlistStore.playlists(of: .regular).filter { playlist in
            playlist.trackIDs.contains { visibleTrackIDs.contains($0) }
                && !playlistStore.tracks(for: playlist.id, in: libraryStore.tracks).isEmpty
        }

        guard !randomizedPlaylistIDs.isEmpty else { return playablePlaylists }

        let playlistsByID = Dictionary(uniqueKeysWithValues: playablePlaylists.map { ($0.id, $0) })
        return randomizedPlaylistIDs.compactMap { playlistsByID[$0] }
    }

    private var homeWorkPlaylists: [Playlist] {
        let workPlaylists = playlistStore.playlists(of: .work)
        let playlistsByID = Dictionary(uniqueKeysWithValues: workPlaylists.map { ($0.id, $0) })
        guard !randomizedPlaylistIDs.isEmpty else { return workPlaylists }
        return randomizedPlaylistIDs.compactMap { playlistsByID[$0] }
    }

    private var homeFavoriteAlbums: [Album] {
        let albumsByID = Dictionary(uniqueKeysWithValues: libraryStore.albums.map { ($0.id, $0) })
        return randomizedFavoriteAlbumIDs.compactMap { albumsByID[$0] }
    }

    private var homeFavoriteArtists: [Artist] {
        let artistsByID = Dictionary(uniqueKeysWithValues: libraryStore.artists.map { ($0.id, $0) })
        return randomizedFavoriteArtistIDs.compactMap { artistsByID[$0] }
    }

    private func randomizeFavoriteAlbums() {
        randomizedFavoriteAlbumIDs = favoriteStore
            .randomFavoriteAlbums(from: libraryStore.albums, limit: 7)
            .map(\.id)
    }

    private func randomizeFavoriteArtists() {
        randomizedFavoriteArtistIDs = favoriteStore
            .randomFavoriteArtists(from: libraryStore.artists, limit: 7)
            .map(\.id)
    }

    private func playPlaylist(_ playlist: Playlist) {
        let playlistTracks = playlistStore.tracks(for: playlist.id, in: libraryStore.tracks)
        let tracks = playlist.kind == .work
            ? playbackHistoryStore.workPlaybackTracks(from: playlistTracks)
            : playbackHistoryStore.preferenceWeightedShuffle(playlistTracks)
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(playlist.kind == .regular)
        playerStore.playQueue(
            tracks,
            startingAt: tracks.startIndex,
            presentationMode: playlist.kind == .work ? .workSize : .standard
        )
    }

    private func artistArtworkIdentifiers(_ artist: Artist) -> [String] {
        Array(Set(libraryStore.tracks(for: artist).compactMap(\.artworkIdentifier)))
    }

    private func artworkIdentifiers(for destination: HomeDestination) -> [String] {
        let tracks: [Track]
        switch destination {
        case .quickPlay:
            tracks = libraryStore.tracks
        case .discoveryPlay:
            tracks = libraryStore.tracks.filter { playbackHistoryStore.playCount(for: $0.id) == 0 }
        case .repeatPlay:
            tracks = playbackHistoryStore.repeatPlayTracks(from: libraryStore.tracks)
        case .selectiveRandomPlay:
            tracks = libraryStore.tracks
        case .workSizePlay:
            tracks = libraryStore.tracks.filter(\.isEligibleForWorkPlayback)
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
            libraryStore.tracks.contains(where: playbackHistoryStore.isEligibleForRegularShuffle)
        case .discoveryPlay:
            libraryStore.tracks.contains {
                playbackHistoryStore.playCount(for: $0.id) == 0
                    && playbackHistoryStore.isEligibleForRegularShuffle($0)
            }
        case .repeatPlay:
            !playbackHistoryStore.repeatPlayTracks(from: libraryStore.tracks, limit: 1).isEmpty
        case .workSizePlay:
            !playbackHistoryStore.workPlaybackTracks(from: libraryStore.tracks).isEmpty
        case .favorites:
            playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
                .contains(where: playbackHistoryStore.isEligibleForRegularShuffle)
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
        case .workSizePlay:
            tracks = playbackHistoryStore.workPlaybackTracks(from: libraryStore.tracks)
        case .favorites:
            tracks = playbackHistoryStore.preferenceWeightedShuffle(
                playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
            )
        default:
            return
        }

        guard !tracks.isEmpty else { return }
        if destination == .workSizePlay {
            playerStore.setShuffleEnabled(false)
        }
        playerStore.playQueue(
            tracks,
            startingAt: 0,
            presentationMode: destination == .workSizePlay ? .workSize : .standard
        )
    }

    private var favoriteAlbumTracks: [Track] {
        uniqueTracks(
            favoriteStore.favoriteAlbums(from: libraryStore.albums)
                .flatMap { libraryStore.tracks(for: $0) }
                .filter(\.isEligibleForRegularPlayback)
        )
    }

    private var favoriteArtistTracks: [Track] {
        uniqueTracks(
            favoriteStore.favoriteArtists(from: libraryStore.artists)
                .flatMap { libraryStore.tracks(for: $0) }
                .filter(\.isEligibleForRegularPlayback)
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

private struct HomeWorkSection: View {
    let category: HomeCategory
    let playlists: [Playlist]
    let showsMore: Bool
    let artworkIdentifiers: (HomeDestination) -> [String]
    let instantPlaybackIsAvailable: (HomeDestination) -> Bool
    let tracksForPlaylist: (Playlist) -> [Track]
    let canPlay: (Playlist) -> Bool
    let onInstantPlay: (HomeDestination) -> Void
    let onPlayPlaylist: (Playlist) -> Void

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
                let width = tileWidth(for: proxy.size.width)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        if let item = category.items.first {
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
                        }

                        if playlists.isEmpty {
                            NavigationLink(value: HomeDestination.workPlaylists) {
                                HomePlaylistEmptyTile(
                                    width: width,
                                    title: "作業用リストを作成",
                                    subtitle: "作業用の曲をまとめる",
                                    systemImage: "timer"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(playlists) { playlist in
                                let tracks = tracksForPlaylist(playlist)
                                let isPlayable = canPlay(playlist)
                                Button { onPlayPlaylist(playlist) } label: {
                                    HomePlaylistTile(
                                        playlist: playlist,
                                        artworkIdentifiers: playlistArtworkIdentifiers(
                                            playlist: playlist,
                                            tracks: tracks
                                        ),
                                        trackCount: tracks.count,
                                        width: width
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(!isPlayable)
                                .opacity(isPlayable ? 1 : 0.55)
                            }

                            if showsMore {
                                NavigationLink(value: HomeDestination.workPlaylists) {
                                    HomePlaylistMoreTile(
                                        width: width,
                                        title: "続きを見る",
                                        subtitle: "すべての作業用リスト"
                                    )
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

private struct HomePlaylistSection: View {
    let playlists: [Playlist]
    let showsMore: Bool
    let tracksForPlaylist: (Playlist) -> [Track]
    let canPlay: (Playlist) -> Bool
    let onPlay: (Playlist) -> Void

    private let spacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let nextTilePeek: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("プレイリスト")
                    .font(.title3.weight(.bold))
                Text("プレイリストをランダムに表示・再生")
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
                                let isPlayable = canPlay(playlist)
                                Button { onPlay(playlist) } label: {
                                    HomePlaylistTile(
                                        playlist: playlist,
                                        artworkIdentifiers: playlistArtworkIdentifiers(playlist: playlist, tracks: tracks),
                                        trackCount: tracks.count,
                                        width: tileWidth
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(!isPlayable)
                                .opacity(isPlayable ? 1 : 0.55)
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
    var title = "もっと見る"
    var subtitle = "すべてのプレイリスト"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.largeTitle)
            Spacer()
            Text(title)
                .font(.headline)
            Text(subtitle)
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
    var title = "プレイリストを作成"
    var subtitle = "曲をまとめて楽しむ"
    var systemImage = "plus.circle.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: systemImage).font(.largeTitle)
            Spacer()
            Text(title).font(.headline).lineLimit(2)
            Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.76)).padding(.top, 3)
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
    let favoriteAlbums: [Album]
    let favoriteArtists: [Artist]
    let artworkIdentifiersForArtist: (Artist) -> [String]
    let albumsForArtist: (Artist) -> [Album]
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
        if item.destination == .favoriteAlbums, !favoriteAlbums.isEmpty {
            ForEach(favoriteAlbums) { album in
                NavigationLink {
                    AlbumShuffleSelectionView(
                        title: album.title,
                        albums: [album]
                    )
                } label: {
                    HomeItemTile(
                        item: HomeCategoryItem(
                            title: album.title,
                            description: "\(album.artistName)・アルバムを選んで再生",
                            systemImage: "square.stack",
                            destination: .favoriteAlbums
                        ),
                        categoryID: category.id,
                        artworkIdentifiers: [album.artworkIdentifier].compactMap { $0 },
                        width: width
                    )
                }
                .buttonStyle(.plain)
            }
        } else if item.destination == .favoriteArtists, !favoriteArtists.isEmpty {
            ForEach(favoriteArtists) { artist in
                NavigationLink {
                    AlbumShuffleSelectionView(
                        title: artist.name,
                        albums: albumsForArtist(artist)
                    )
                } label: {
                    HomeItemTile(
                        item: HomeCategoryItem(
                            title: artist.name,
                            description: "アルバムを選んでランダム再生",
                            systemImage: "person.crop.square",
                            destination: .favoriteArtists
                        ),
                        categoryID: category.id,
                        artworkIdentifiers: artworkIdentifiersForArtist(artist),
                        width: width
                    )
                }
                .buttonStyle(.plain)
            }
        } else if isInstantPlaybackDestination(item.destination) {
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
        case .quickPlay, .discoveryPlay, .repeatPlay, .workSizePlay, .favorites:
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
                .opacity(item.destination == .selectiveRandomPlay ? 1 : (colorScheme == .dark ? 0.68 : 0.58))
                .overlay {
                    if item.destination == .selectiveRandomPlay {
                        selectiveRandomGradient.opacity(0.5)
                    }
                }
                .overlay(item.destination == .selectiveRandomPlay ? selectiveRandomReadabilityMask : readabilityMask)
        } else if item.destination == .selectiveRandomPlay {
            selectiveRandomGradient
                .overlay(selectiveRandomReadabilityMask)
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

    private var selectiveRandomGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.60, green: 0.10, blue: 0.27),
                Color(red: 0.62, green: 0.33, blue: 0.08),
                Color(red: 0.08, green: 0.42, blue: 0.30),
                Color(red: 0.07, green: 0.29, blue: 0.58),
                Color(red: 0.31, green: 0.13, blue: 0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectiveRandomReadabilityMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.22), location: 0),
                .init(color: .black.opacity(0.38), location: 0.48),
                .init(color: .black.opacity(0.70), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
        if item.destination == .selectiveRandomPlay { return .white }
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
