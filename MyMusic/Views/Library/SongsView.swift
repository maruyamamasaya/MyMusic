import SwiftUI

struct SongsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var trackToAddToPlaylist: Track?
    @State private var query = ""
    @State private var sortOrder: SongSortOrder = .title
    @State private var displayedTrackCount = pageSize
    @State private var randomSeed = UInt64.random(in: .min ... .max)

    private static let pageSize = 100

    let tracks: [Track]
    let title: String

    init(tracks: [Track] = PreviewData.tracks, title: String = "曲") {
        self.tracks = tracks
        self.title = title
    }

    private var arrangedTracks: [Track] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredTracks = trimmedQuery.isEmpty ? tracks : tracks.filter { track in
            track.title.localizedStandardContains(trimmedQuery)
                || track.artistName.localizedStandardContains(trimmedQuery)
                || (track.albumTitle?.localizedStandardContains(trimmedQuery) == true)
        }

        return filteredTracks.sorted { lhs, rhs in
            switch sortOrder {
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
                let lhsRank = randomRank(for: lhs.id)
                let rhsRank = randomRank(for: rhs.id)
                return lhsRank == rhsRank ? lhs.id.uuidString < rhs.id.uuidString : lhsRank < rhsRank
            }
        }
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

                if arrangedTracks.isEmpty {
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
                sortMenu
            }
        }
        .onChange(of: query) { _, _ in resetPagination() }
        .onChange(of: sortOrder) { _, _ in resetPagination() }
        .onChange(of: tracks.map(\.id)) { _, _ in resetPagination() }
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
            PlayableTrackRowView(track: track) {
                guard let index = arrangedTracks.firstIndex(where: { $0.id == track.id }) else { return }
                playerStore.playQueue(arrangedTracks, startingAt: index)
            }
        }
        .contextMenu {
            Button(
                playbackHistoryStore.isFavorite(trackID: track.id) ? "お気に入りから削除" : "お気に入りに追加",
                systemImage: playbackHistoryStore.isFavorite(trackID: track.id) ? "heart.slash" : "heart"
            ) {
                playbackHistoryStore.toggleFavorite(trackID: track.id)
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

    private func compare(_ lhsValue: String, _ rhsValue: String, lhs: Track, rhs: Track) -> Bool {
        let result = lhsValue.localizedStandardCompare(rhsValue)
        if result != .orderedSame { return result == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func randomRank(for id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(1_469_598_103_934_665_603 ^ randomSeed) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

private enum SongSortOrder: String, CaseIterable, Identifiable {
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
