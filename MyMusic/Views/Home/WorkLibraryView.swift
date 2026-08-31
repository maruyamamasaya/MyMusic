import SwiftUI

enum WorkLibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case songs
    case albums
    case artists
    case albumArtists
    case playlists

    var id: Self { self }

    var title: String {
        switch self {
        case .songs: "曲名"
        case .albums: "アルバム"
        case .artists: "アーティスト"
        case .albumArtists: "アルバムアーティスト"
        case .playlists: "プレイリスト"
        }
    }

    var description: String {
        switch self {
        case .songs: "作業用の曲を曲名から探す"
        case .albums: "作業用の曲をアルバム別に表示"
        case .artists: "作業用の曲をアーティスト別に表示"
        case .albumArtists: "作業用の曲をアルバムアーティスト別に表示"
        case .playlists: "作業用プレイリストを表示"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .albums: "square.stack"
        case .artists: "music.mic"
        case .albumArtists: "person.2.fill"
        case .playlists: "music.note.list"
        }
    }
}

struct WorkLibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaylistStore.self) private var playlistStore

    private var catalog: WorkLibraryCatalog { libraryStore.workLibraryCatalog }

    var body: some View {
        List {
            Section {
                ForEach(WorkLibraryCategory.allCases) { category in
                    NavigationLink(value: category) {
                        categoryRow(category)
                    }
                }
            } header: {
                Text("作業用ライブラリ")
            } footer: {
                Text("20分以上、またはジャンルが「作業用BGM」の曲だけを表示します。")
            }
        }
        .navigationTitle("作業用サイズ再生")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: WorkLibraryCategory.self) { category in
            destination(for: category)
        }
        .task { await playlistStore.loadIfNeeded() }
    }

    private func categoryRow(_ category: WorkLibraryCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.headline)
                Text(category.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("\(itemCount(for: category))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }

    private func itemCount(for category: WorkLibraryCategory) -> Int {
        switch category {
        case .songs: catalog.tracks.count
        case .albums: catalog.albums.count
        case .artists: catalog.artists.count
        case .albumArtists: catalog.albumArtists.count
        case .playlists: playlistStore.playlists(of: .work).count
        }
    }

    @ViewBuilder
    private func destination(for category: WorkLibraryCategory) -> some View {
        switch category {
        case .songs:
            WorkTrackCollectionView(
                title: category.title,
                emptyTitle: "作業用の曲はありません",
                tracks: catalog.tracks,
                searchPrompt: "曲名を検索",
                matchesSearch: { track, query in
                    track.title.localizedStandardContains(query)
                }
            )
        case .albums:
            WorkAlbumsView(catalog: catalog)
        case .artists:
            WorkArtistsView(catalog: catalog)
        case .albumArtists:
            WorkAlbumArtistsView(catalog: catalog)
        case .playlists:
            WorkPlaylistView(createsNavigationStack: false)
        }
    }
}

private struct WorkAlbumsView: View {
    @State private var query = ""
    let catalog: WorkLibraryCatalog

    private var filteredAlbums: [Album] {
        guard !trimmedQuery.isEmpty else { return catalog.albums }
        return catalog.albums.filter {
            $0.title.localizedStandardContains(trimmedQuery)
                || $0.artistName.localizedStandardContains(trimmedQuery)
        }
    }

    var body: some View {
        List {
            if filteredAlbums.isEmpty {
                emptyState(title: "作業用のアルバムはありません")
            } else {
                ForEach(filteredAlbums) { album in
                    NavigationLink {
                        WorkTrackCollectionView(
                            title: album.title,
                            subtitle: album.artistName,
                            emptyTitle: "曲がありません",
                            tracks: catalog.tracks(for: album.trackIDs)
                        )
                    } label: {
                        HStack(spacing: 12) {
                            AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(album.title).lineLimit(1)
                                Text(album.artistName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("アルバム")
        .searchable(text: $query, prompt: "アルバムを検索")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private func emptyState(title: String) -> some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView(title, systemImage: "square.stack")
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}

private struct WorkArtistsView: View {
    @State private var query = ""
    let catalog: WorkLibraryCatalog

    private var filteredArtists: [Artist] {
        guard !trimmedQuery.isEmpty else { return catalog.artists }
        return catalog.artists.filter { $0.name.localizedStandardContains(trimmedQuery) }
    }

    var body: some View {
        List {
            if filteredArtists.isEmpty {
                emptyState
            } else {
                ForEach(filteredArtists) { artist in
                    NavigationLink {
                        WorkTrackCollectionView(
                            title: artist.name,
                            emptyTitle: "曲がありません",
                            tracks: catalog.tracks(for: artist.trackIDs)
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artist.name)
                                Text("\(artist.trackIDs.count)曲")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.mic")
                        }
                    }
                }
            }
        }
        .navigationTitle("アーティスト")
        .searchable(text: $query, prompt: "アーティストを検索")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var emptyState: some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView("作業用のアーティストはいません", systemImage: "music.mic")
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}

private struct WorkAlbumArtistsView: View {
    @State private var query = ""
    let catalog: WorkLibraryCatalog

    private var filteredAlbumArtists: [WorkAlbumArtist] {
        guard !trimmedQuery.isEmpty else { return catalog.albumArtists }
        return catalog.albumArtists.filter { $0.name.localizedStandardContains(trimmedQuery) }
    }

    var body: some View {
        List {
            if filteredAlbumArtists.isEmpty {
                emptyState
            } else {
                ForEach(filteredAlbumArtists) { albumArtist in
                    NavigationLink {
                        WorkTrackCollectionView(
                            title: albumArtist.name,
                            emptyTitle: "曲がありません",
                            tracks: catalog.tracks(for: albumArtist.trackIDs)
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(albumArtist.name)
                                Text("\(albumArtist.trackIDs.count)曲")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.2.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle("アルバムアーティスト")
        .searchable(text: $query, prompt: "アルバムアーティストを検索")
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var emptyState: some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView("作業用のアルバムアーティストはいません", systemImage: "person.2.fill")
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}

private struct WorkTrackCollectionView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var query = ""

    let title: String
    var subtitle: String? = nil
    let emptyTitle: String
    let tracks: [Track]
    var searchPrompt = "曲名、アーティスト、アルバムを検索"
    var matchesSearch: (Track, String) -> Bool = { track, query in
        track.title.localizedStandardContains(query)
            || track.artistName.localizedStandardContains(query)
            || (track.albumTitle?.localizedStandardContains(query) == true)
            || (track.albumArtistName?.localizedStandardContains(query) == true)
    }

    private var filteredTracks: [Track] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return tracks }
        return tracks.filter { matchesSearch($0, trimmedQuery) }
    }

    var body: some View {
        List {
            if let subtitle {
                Section {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
            }

            if !filteredTracks.isEmpty {
                Section {
                    PlayShuffleButtons(
                        isDisabled: filteredTracks.isEmpty,
                        onPlay: { play(shuffled: false) },
                        onShuffle: { play(shuffled: true) }
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }

            Section("曲") {
                if filteredTracks.isEmpty {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(emptyTitle, systemImage: "timer")
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                } else {
                    ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                        PlayableTrackRowView(track: track) {
                            playTrack(at: index)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: searchPrompt)
    }

    private func play(shuffled: Bool) {
        let playbackTracks = shuffled
            ? playbackHistoryStore.workPlaybackTracks(from: filteredTracks)
            : filteredTracks
        guard !playbackTracks.isEmpty else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            playbackTracks,
            startingAt: 0,
            presentationMode: .workSize,
            startContext: PlaybackStartContext(kind: .manual, source: shuffled ? .shuffle : .workLibrary)
        )
    }

    private func playTrack(at index: Int) {
        guard filteredTracks.indices.contains(index) else { return }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            filteredTracks,
            startingAt: index,
            presentationMode: .workSize,
            startContext: PlaybackStartContext(kind: .manual, source: .workLibrary)
        )
    }
}
