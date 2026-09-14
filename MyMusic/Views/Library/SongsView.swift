import SwiftUI

struct SongsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @State private var trackToAddToPlaylist: Track?
    @State private var query = ""
    @State private var sortOrder: SongSortOrder = .random
    @State private var filter = SongListFilter.all
    @State private var displayedTrackCount = pageSize
    @State private var randomSeed = UInt64.random(in: .min ... .max)
    @State private var arrangedTracks: [Track] = []
    @State private var isPreparingTracks = true
    @AppStorage("library.songsDisplayMode") private var displayMode = LibraryDisplayMode.artwork

    private static let pageSize = 100

    let tracks: [Track]
    let title: String

    init(tracks: [Track] = PreviewData.tracks, title: String = "曲") {
        self.tracks = tracks
        self.title = title
    }

    private var visibleTracks: [Track] {
        Array(arrangedTracks.prefix(displayedTrackCount))
    }

    var body: some View {
        List {
            Section(title) {
                ForEach(visibleTracks) { track in
                    trackRow(track)
                        .onAppear {
                            loadNextPageIfNeeded(after: track)
                        }
                }

                if isPreparingTracks {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("曲を準備中…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .accessibilityElement(children: .combine)
                } else if arrangedTracks.isEmpty {
                    ContentUnavailableView(
                        "条件に一致する曲がありません",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("検索または絞り込み条件を変更してください。")
                    )
                }
            }
        }
        .themeScreen()
        .navigationTitle(title)
        .searchable(text: $query, prompt: "曲、アーティスト、アルバム、ジャンル")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LibraryDisplayModeMenu(selection: $displayMode)
            }
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .onChange(of: query) { _, _ in resetPagination() }
        .onChange(of: sortOrder) { _, _ in resetPagination() }
        .onChange(of: filter) { _, _ in resetPagination() }
        .task(id: arrangementRequest) {
            await prepareTracks()
        }
        .sheet(item: $trackToAddToPlaylist) { track in
            AddToPlaylistSheet(track: track)
        }
    }

    private func trackRow(_ track: Track) -> some View {
        HStack(spacing: 4) {
            if playerStore.currentTrack?.id == track.id {
                Image(systemName: playerStore.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                    .foregroundStyle(.tint)
                    .frame(width: 18)
            }
            PlayableTrackRowView(track: track, showsArtwork: displayMode == .artwork) {
                guard let index = arrangedTracks.firstIndex(where: { $0.id == track.id }) else { return }
                playerStore.playQueue(
                    arrangedTracks,
                    startingAt: index,
                    startContext: PlaybackStartContext(kind: .manual, source: .library)
                )
            }
        }
        .contextMenu {
            if track.isEligibleForRegularPlayback {
                Button(
                    preferenceStore.isFavorite(trackID: track.id) ? "お気に入りから削除" : "お気に入りに追加",
                    systemImage: preferenceStore.isFavorite(trackID: track.id) ? "heart.slash" : "heart"
                ) {
                    preferenceStore.toggleFavorite(trackID: track.id)
                }
            }
            Button("プレイリストに追加", systemImage: "text.badge.plus") {
                trackToAddToPlaylist = track
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("表示順", selection: $sortOrder) {
                ForEach(SongSortOrder.allCases) { order in
                    Label(order.title, systemImage: order.systemImage).tag(order)
                }
            }

            if sortOrder == .random {
                Button("もう一度シャッフル", systemImage: "shuffle") {
                    randomSeed = UInt64.random(in: .min ... .max)
                    resetPagination()
                }
            }
        } label: {
            Label("表示順", systemImage: "arrow.up.arrow.down")
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("絞り込み", selection: $filter) {
                ForEach(SongListFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.systemImage).tag(filter)
                }
            }
        } label: {
            Label(
                filter == .all ? "絞り込み" : "絞り込み: \(filter.title)",
                systemImage: filter == .all
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }

    private func loadNextPageIfNeeded(after track: Track) {
        guard track.id == visibleTracks.last?.id, displayedTrackCount < arrangedTracks.count else { return }
        displayedTrackCount = min(displayedTrackCount + Self.pageSize, arrangedTracks.count)
    }

    private func resetPagination() {
        displayedTrackCount = Self.pageSize
    }

    private var arrangementRequest: SongArrangementRequest {
        SongArrangementRequest(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            filter: filter,
            sortOrder: sortOrder,
            randomSeed: randomSeed,
            trackCount: tracks.count,
            preferenceRevision: preferenceStore.homePresentationRevision,
            historyRevision: playbackHistoryStore.homePresentationRevision
        )
    }

    @MainActor
    private func prepareTracks() async {
        isPreparingTracks = true

        // Typing into search should not start a full-library pass for every keystroke.
        if !query.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
        }

        let sourceTracks = tracks
        let request = arrangementRequest
        let preferences = preferenceStore.entries
        let histories = playbackHistoryStore.entries
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.arrange(
                sourceTracks,
                request: request,
                preferences: preferences,
                histories: histories
            )
        }.value

        guard !Task.isCancelled, request == arrangementRequest else { return }
        arrangedTracks = prepared
        resetPagination()
        isPreparingTracks = false
    }

    nonisolated static func arrange(
        _ tracks: [Track],
        request: SongArrangementRequest,
        preferences: [Track.ID: TrackPreference],
        histories: [Track.ID: PlaybackHistory],
        now: Date = Date()
    ) -> [Track] {
        var filteredTracks = request.query.isEmpty ? tracks : tracks.filter { track in
            track.title.localizedStandardContains(request.query)
                || track.artistName.localizedStandardContains(request.query)
                || (track.albumTitle?.localizedStandardContains(request.query) == true)
                || (track.genre?.localizedStandardContains(request.query) == true)
        }

        filteredTracks = filteredTracks.filter { track in
            request.filter.includes(
                track,
                preference: preferences[track.id],
                history: histories[track.id],
                now: now
            )
        }

        if request.sortOrder == .random {
            filteredTracks.removeAll { !$0.isEligibleForRegularPlayback }
        }

        return filteredTracks.sorted { lhs, rhs in
            switch request.sortOrder {
            case .title:
                return compare(lhs.title, rhs.title, lhs: lhs, rhs: rhs)
            case .artist:
                return compare(lhs.artistName, rhs.artistName, lhs: lhs, rhs: rhs)
            case .album:
                return compare(lhs.albumTitle ?? "", rhs.albumTitle ?? "", lhs: lhs, rhs: rhs)
            case .modifiedDate:
                if lhs.modificationDate != rhs.modificationDate {
                    return (lhs.modificationDate ?? .distantPast) > (rhs.modificationDate ?? .distantPast)
                }
                return compare(lhs.title, rhs.title, lhs: lhs, rhs: rhs)
            case .playCount:
                let lhsCount = histories[lhs.id]?.playCount ?? 0
                let rhsCount = histories[rhs.id]?.playCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return compare(lhs.title, rhs.title, lhs: lhs, rhs: rhs)
            case .lastPlayed:
                let lhsDate = histories[lhs.id]?.lastPlayedAt ?? .distantPast
                let rhsDate = histories[rhs.id]?.lastPlayedAt ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return compare(lhs.title, rhs.title, lhs: lhs, rhs: rhs)
            case .duration:
                if lhs.duration != rhs.duration { return lhs.duration < rhs.duration }
                return compare(lhs.title, rhs.title, lhs: lhs, rhs: rhs)
            case .random:
                let lhsRank = randomRank(for: lhs.id, seed: request.randomSeed)
                let rhsRank = randomRank(for: rhs.id, seed: request.randomSeed)
                return lhsRank == rhsRank ? lhs.id.uuidString < rhs.id.uuidString : lhsRank < rhsRank
            }
        }
    }

    nonisolated private static func compare(_ lhsValue: String, _ rhsValue: String, lhs: Track, rhs: Track) -> Bool {
        let result = lhsValue.localizedStandardCompare(rhsValue)
        if result != .orderedSame { return result == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    nonisolated private static func randomRank(for id: UUID, seed: UInt64) -> UInt64 {
        id.uuidString.utf8.reduce(1_469_598_103_934_665_603 ^ seed) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

nonisolated struct SongArrangementRequest: Hashable, Sendable {
    let query: String
    let filter: SongListFilter
    let sortOrder: SongSortOrder
    let randomSeed: UInt64
    let trackCount: Int
    let preferenceRevision: Int
    let historyRevision: Int
}

nonisolated enum SongSortOrder: String, CaseIterable, Identifiable, Sendable {
    case title
    case artist
    case album
    case modifiedDate
    case playCount
    case lastPlayed
    case duration
    case random

    var id: Self { self }

    var title: String {
        switch self {
        case .title: "曲名"
        case .artist: "アーティスト"
        case .album: "アルバム"
        case .modifiedDate: "追加・更新日（新しい順）"
        case .playCount: "再生回数（多い順）"
        case .lastPlayed: "最近再生した順"
        case .duration: "曲の長さ（短い順）"
        case .random: "ランダム"
        }
    }

    var systemImage: String {
        switch self {
        case .title: "textformat"
        case .artist: "music.mic"
        case .album: "square.stack"
        case .modifiedDate: "clock"
        case .playCount: "play.circle"
        case .lastPlayed: "clock.arrow.circlepath"
        case .duration: "timer"
        case .random: "shuffle"
        }
    }
}

nonisolated enum SongListFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case favorites
    case good
    case bad
    case played
    case unplayed
    case recentlyAdded

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "すべて"
        case .favorites: "お気に入り"
        case .good: "Good"
        case .bad: "Bad"
        case .played: "再生済み"
        case .unplayed: "未再生"
        case .recentlyAdded: "最近追加"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "music.note.list"
        case .favorites: "heart.fill"
        case .good: "hand.thumbsup.fill"
        case .bad: "hand.thumbsdown.fill"
        case .played: "play.circle.fill"
        case .unplayed: "sparkles"
        case .recentlyAdded: "clock.badge.plus"
        }
    }

    func includes(
        _ track: Track,
        preference: TrackPreference?,
        history: PlaybackHistory?,
        now: Date
    ) -> Bool {
        switch self {
        case .all:
            true
        case .favorites:
            preference?.favorite == true
        case .good:
            (preference?.playbackPreference ?? 0) > 0
        case .bad:
            (preference?.playbackPreference ?? 0) < 0
        case .played:
            (history?.playCount ?? 0) > 0
        case .unplayed:
            (history?.playCount ?? 0) == 0
        case .recentlyAdded:
            track.firstSeenAt.map {
                $0 <= now && now.timeIntervalSince($0) <= PlaybackHistoryStore.recentlyAddedInterval
            } == true
        }
    }
}
