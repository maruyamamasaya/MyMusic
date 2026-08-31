import SwiftUI

enum HomeWorkTileLayout {
    static let maximumTileCount = 12
    static let fixedPlaybackTileCount = 1
    static let continuationTileCount = 1
    static let maximumPlaylistCount = maximumTileCount - fixedPlaybackTileCount - continuationTileCount

    static func showsContinuationTile(for playlistCount: Int) -> Bool {
        playlistCount > maximumPlaylistCount
    }
}

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(FavoriteStore.self) private var favoriteStore
    @State private var randomizedPlaylistIDs: [Playlist.ID] = []

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(HomeCategory.all.filter { $0.id != .playback }) { category in
                        if category.id == .myMusic, !libraryStore.genreDisplayPresets.isEmpty {
                            HomeTuningSection(
                                presets: libraryStore.genreDisplayPresets,
                                allGenresAreEnabled: libraryStore.areAllGenresEnabled,
                                isActive: libraryStore.isGenreDisplayPresetActive,
                                onShowAllGenres: libraryStore.showAllGenres,
                                onApply: libraryStore.applyGenreDisplayPreset
                            )
                        }
                        HomeCarouselSection(
                            category: category,
                            artworkIdentifiers: artworkIdentifiers,
                            instantPlaybackIsAvailable: instantPlaybackIsAvailable,
                            onInstantPlay: playImmediately
                        )
                        if category.id == .myMusic {
                            if !homePlaylists.isEmpty {
                                HomePlaylistSection(
                                    playlists: Array(homePlaylists.prefix(12)),
                                    showsMore: homePlaylists.count > 12,
                                    tracksForPlaylist: { playlistStore.tracks(for: $0.id, in: libraryStore.tracks) },
                                    canPlay: { playlist in
                                        playlistStore.tracks(for: playlist.id, in: libraryStore.tracks)
                                            .contains(where: playbackHistoryStore.isEligibleForRegularShuffle)
                                    },
                                    onPlay: playPlaylist
                                )
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ステーション").font(.title3.bold())
                                StationEntryView()
                            }
                            .padding(.horizontal, 16)

                            if let workCategory = HomeCategory.all.first(where: { $0.id == .playback }) {
                                HomeWorkSection(
                                    category: workCategory,
                                    playlists: Array(
                                        homeWorkPlaylists.prefix(HomeWorkTileLayout.maximumPlaylistCount)
                                    ),
                                    showsMore: HomeWorkTileLayout.showsContinuationTile(
                                        for: homeWorkPlaylists.count
                                    ),
                                    artworkIdentifiers: artworkIdentifiers,
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
                                    onPlayPlaylist: playPlaylist
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
        case .favorites:
            tracks = playbackHistoryStore.preferenceWeightedShuffle(
                playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
            )
        default:
            return
        }

        guard !tracks.isEmpty else { return }
        playerStore.playQueue(
            tracks,
            startingAt: 0,
            presentationMode: .standard
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
    let allGenresAreEnabled: Bool
    let isActive: (GenreDisplayPreset) -> Bool
    let onShowAllGenres: () -> Void
    let onApply: (GenreDisplayPreset) -> Void

    @State private var appliedPresetName: String?

    private let spacing: CGFloat = 10
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("チューニング").font(.title3.weight(.bold))
                    Text("シーンに合わせてライブラリの表示を切り替え")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("設定中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(activePresetName ?? "未選択")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, horizontalPadding)

            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    Button {
                        onShowAllGenres()
                        appliedPresetName = "全曲表示"
                    } label: {
                        HomeTuningTag(title: "全曲表示", isActive: allGenresAreEnabled, paletteIndex: 0)
                    }
                    .buttonStyle(.plain)

                    ForEach(presets) { preset in
                        Button {
                            onApply(preset)
                            appliedPresetName = preset.name
                        } label: {
                            HomeTuningTag(
                                title: preset.name,
                                isActive: !allGenresAreEnabled && isActive(preset),
                                paletteIndex: paletteIndex(for: preset)
                            )
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
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .alert("設定しました", isPresented: appliedPresetIsPresented) {
            Button("OK", role: .cancel) { appliedPresetName = nil }
        } message: {
            if let appliedPresetName {
                Text("「\(appliedPresetName)」を設定しました。")
            }
        }
    }

    private var activePresetName: String? {
        if allGenresAreEnabled { return "全曲表示" }
        return presets.first(where: isActive)?.name
    }

    private func paletteIndex(for preset: GenreDisplayPreset) -> Int {
        1 + preset.id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 6 }
    }

    private var appliedPresetIsPresented: Binding<Bool> {
        Binding(
            get: { appliedPresetName != nil },
            set: { if !$0 { appliedPresetName = nil } }
        )
    }
}

private struct HomeTuningTag: View {
    let title: String
    let isActive: Bool
    let paletteIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark" : "tuningfork")
                .font(.caption.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .frame(minHeight: 44)
        .fixedSize(horizontal: true, vertical: false)
        .background(tagGradient, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(isActive ? 0.9 : 0.18), lineWidth: isActive ? 2 : 0.5)
        }
        .contentShape(Capsule())
        .accessibilityLabel("チューニング、\(title)")
        .accessibilityValue(isActive ? "適用中" : "未適用")
        .accessibilityHint(isActive ? "現在適用中です" : "ライブラリの表示を切り替えます")
    }

    private var tagGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: gradientStartsAtTopTrailing ? .topTrailing : .topLeading,
            endPoint: gradientStartsAtTopTrailing ? .bottomLeading : .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.12, green: 0.48, blue: 0.88), Color(red: 0.18, green: 0.14, blue: 0.60)],
            [Color(red: 0.85, green: 0.18, blue: 0.45), Color(red: 0.44, green: 0.14, blue: 0.62)],
            [Color(red: 0.05, green: 0.55, blue: 0.42), Color(red: 0.02, green: 0.31, blue: 0.38)],
            [Color(red: 0.78, green: 0.31, blue: 0.05), Color(red: 0.68, green: 0.12, blue: 0.18)],
            [Color(red: 0.58, green: 0.26, blue: 0.85), Color(red: 0.27, green: 0.15, blue: 0.60)],
            [Color(red: 0.00, green: 0.52, blue: 0.68), Color(red: 0.05, green: 0.30, blue: 0.66)],
            [Color(red: 0.25, green: 0.58, blue: 0.16), Color(red: 0.03, green: 0.38, blue: 0.30)]
        ]
        return palettes[paletteIndex]
    }

    private var gradientStartsAtTopTrailing: Bool {
        paletteIndex.isMultiple(of: 2)
    }
}

private struct HomeWorkSection: View {
    let category: HomeCategory
    let playlists: [Playlist]
    let showsMore: Bool
    let artworkIdentifiers: (HomeDestination) -> [String]
    let tracksForPlaylist: (Playlist) -> [Track]
    let canPlay: (Playlist) -> Bool
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
    @State private var localBackgroundImage: UIImage?

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
        .task(id: item.localBackgroundImageName) { loadLocalBackgroundImage() }
    }

    @ViewBuilder
    private var tileBackground: some View {
        if let localBackgroundImage {
            GeometryReader { proxy in
                Image(uiImage: localBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .overlay(localImageReadabilityMask)
        } else if categoryID == .myMusic, let selectedArtworkIdentifier {
            HomeTileArtworkBackground(artworkIdentifier: selectedArtworkIdentifier)
                .overlay(playlistStyleReadabilityMask)
        } else if categoryID == .myMusic {
            playlistStyleFallbackBackground
                .overlay(playlistStyleReadabilityMask)
        } else if let selectedArtworkIdentifier {
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

    private var playlistStyleFallbackBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.25, green: 0.29, blue: 0.40),
                Color(red: 0.08, green: 0.09, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var playlistStyleReadabilityMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.20), location: 0),
                .init(color: .black.opacity(0.38), location: 0.48),
                .init(color: .black.opacity(0.88), location: 1)
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
        case .musicHistory:
            [
                Color(red: 0.96, green: 0.58, blue: 0.20),
                Color(red: 0.82, green: 0.24, blue: 0.30),
                Color(red: 0.34, green: 0.08, blue: 0.24)
            ]
        default:
            [Color.accentColor, Color.accentColor.opacity(0.65), Color.black.opacity(0.72)]
        }
    }

    private var gradientStartsAtTopTrailing: Bool {
        switch item.destination {
        case .albums, .genres, .analytics, .musicHistory: true
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

    private var localImageReadabilityMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.18), location: 0),
                .init(color: .black.opacity(0.34), location: 0.48),
                .init(color: .black.opacity(0.76), location: 1)
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
        if localBackgroundImage != nil { return .white }
        if categoryID == .myMusic { return .white }
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

    private func loadLocalBackgroundImage() {
        guard let imageName = item.localBackgroundImageName else {
            localBackgroundImage = nil
            return
        }
        localBackgroundImage = HomeTileBackgroundImage.load(named: imageName)
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
