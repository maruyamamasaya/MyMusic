import SwiftUI

struct SongsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @State private var trackToAddToPlaylist: Track?
    @State private var query = ""
    @State private var sortOrder: SongSortOrder = .random
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
                        "検索結果がありません",
                        systemImage: "magnifyingglass",
                        description: Text("別のキーワードを試してください。")
                    )
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $query, prompt: "曲、アーティスト、アルバム")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LibraryDisplayModeMenu(selection: $displayMode)
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
        .onChange(of: query) { _, _ in resetPagination() }
        .onChange(of: sortOrder) { _, _ in resetPagination() }
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

    private func loadNextPageIfNeeded(after track: Track) {
        guard track.id == visibleTracks.last?.id, displayedTrackCount < arrangedTracks.count else { return }
        displayedTrackCount = min(displayedTrackCount + Self.pageSize, arrangedTracks.count)
    }

    private func resetPagination() {
        displayedTrackCount = Self.pageSize
    }

    private var arrangementRequest: ArrangementRequest {
        ArrangementRequest(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: sortOrder,
            randomSeed: randomSeed,
            trackCount: tracks.count
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
        let prepared = await Task.detached(priority: .userInitiated) {
            Self.arrange(sourceTracks, request: request)
        }.value

        guard !Task.isCancelled, request == arrangementRequest else { return }
        arrangedTracks = prepared
        resetPagination()
        isPreparingTracks = false
    }

    nonisolated private static func arrange(_ tracks: [Track], request: ArrangementRequest) -> [Track] {
        var filteredTracks = request.query.isEmpty ? tracks : tracks.filter { track in
            track.title.localizedStandardContains(request.query)
                || track.artistName.localizedStandardContains(request.query)
                || (track.albumTitle?.localizedStandardContains(request.query) == true)
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

private struct ArrangementRequest: Hashable, Sendable {
    let query: String
    let sortOrder: SongSortOrder
    let randomSeed: UInt64
    let trackCount: Int
}

private enum SongSortOrder: String, CaseIterable, Identifiable, Sendable {
    case title
    case artist
    case album
    case modifiedDate
    case random

    var id: Self { self }

    var title: String {
        switch self {
        case .title: "曲名"
        case .artist: "アーティスト"
        case .album: "アルバム"
        case .modifiedDate: "追加・更新日（新しい順）"
        case .random: "ランダム"
        }
    }

    var systemImage: String {
        switch self {
        case .title: "textformat"
        case .artist: "music.mic"
        case .album: "square.stack"
        case .modifiedDate: "clock"
        case .random: "shuffle"
        }
    }
}
