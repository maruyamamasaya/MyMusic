import SwiftUI

struct PlaylistDetailView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    let playlistID: Playlist.ID

    @State private var isEditingPlaylist = false
    @State private var editMode: EditMode = .inactive
    @State private var selectedTracks: Set<Track.ID> = []
    @State private var isAddingSongs = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var syncResult: PlaylistSyncResult?

    private let exporter = MusicDataExportService()
    private let searchService = TrackSearchService()
    private var playlist: Playlist? { playlistStore.playlist(id: playlistID) }
    private var tracks: [Track] { playlistStore.tracks(for: playlistID, in: libraryStore.tracks) }

    var body: some View {
        List {
            if playlist != nil {
                controls
                Section("曲") {
                    if tracks.isEmpty {
                        ContentUnavailableView("曲がありません", systemImage: "music.note.list", description: Text("編集からライブラリの曲を追加できます。"))
                    } else {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            if isEditingPlaylist { selectionRow(track) }
                            else { PlayableTrackRowView(track: track) { playerStore.playQueue(tracks, startingAt: index) } }
                        }
                        .onMove { playlistStore.moveTracks(in: playlistID, from: $0, to: $1) }
                    }
                }
                if isEditingPlaylist {
                    Section {
                        Button("選択した\(selectedTracks.count)曲を削除", systemImage: "trash", role: .destructive) {
                            playlistStore.removeTracks(selectedTracks, from: playlistID); selectedTracks.removeAll()
                        }.disabled(selectedTracks.isEmpty)
                    } footer: { Text("曲はプレイリストからのみ削除され、音楽ファイルや他のデータには影響しません。") }
                }
            } else {
                ContentUnavailableView("プレイリストが見つかりません", systemImage: "questionmark.folder")
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(playlist?.name ?? "プレイリスト")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditingPlaylist ? "完了" : "編集") {
                    isEditingPlaylist.toggle()
                    editMode = isEditingPlaylist ? .active : .inactive
                    if !isEditingPlaylist { selectedTracks.removeAll() }
                }.disabled(playlist == nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                if playlist?.searchDefinition != nil {
                    Button("検索条件で更新", systemImage: "arrow.triangle.2.circlepath") {
                        synchronizeWithSearch()
                    }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                if let playlist, let json = try? exporter.playlistJSON(playlist, tracks: tracks) {
                    ShareLink(item: json, preview: SharePreview("\(playlist.name).json")) { Label("JSONで書き出す", systemImage: "curlybraces") }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                if let playlist {
                    ShareLink(item: exporter.playlistMarkdown(playlist, tracks: tracks), preview: SharePreview("\(playlist.name).md")) {
                        Label("Markdownで書き出す", systemImage: "doc.plaintext")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingSongs) { AddSongsToPlaylistView(playlistID: playlistID) }
        .alert("プレイリスト名を変更", isPresented: $isRenaming) {
            TextField("プレイリスト名", text: $renameText)
            Button("キャンセル", role: .cancel) { }
            Button("保存") { playlistStore.renamePlaylist(id: playlistID, to: renameText) }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("プレイリストを更新しました", isPresented: syncResultIsPresented) {
            Button("閉じる", role: .cancel) { syncResult = nil }
        } message: {
            if let syncResult {
                Text("追加 \(syncResult.addedCount)曲、削除 \(syncResult.removedCount)曲、合計 \(syncResult.totalCount)曲です。")
            }
        }
        .onDisappear {
            isEditingPlaylist = false
            editMode = .inactive
            selectedTracks.removeAll()
        }
    }

    private var controls: some View {
        Section {
            if isEditingPlaylist {
                Button("曲を追加", systemImage: "plus") { isAddingSongs = true }
                Button("名前を変更", systemImage: "pencil") {
                    renameText = playlist?.name ?? ""; isRenaming = true
                }
            } else {
                PlayShuffleButtons(
                    isDisabled: tracks.isEmpty,
                    onPlay: { play(shuffled: false) },
                    onShuffle: { play(shuffled: true) }
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func selectionRow(_ track: Track) -> some View {
        Button {
            if !selectedTracks.insert(track.id).inserted { selectedTracks.remove(track.id) }
        } label: {
            HStack {
                Image(systemName: selectedTracks.contains(track.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTracks.contains(track.id) ? Color.accentColor : .secondary)
                VStack(alignment: .leading) {
                    Text(track.title).foregroundStyle(.primary).lineLimit(1)
                    Text(track.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }

    private var syncResultIsPresented: Binding<Bool> {
        Binding(get: { syncResult != nil }, set: { if !$0 { syncResult = nil } })
    }

    private func synchronizeWithSearch() {
        guard let definition = playlist?.searchDefinition else { return }
        let matchedTracks = searchService.search(
            tracks: libraryStore.tracks,
            query: definition.query,
            filter: definition.filter,
            historyEntries: playbackHistoryStore.entries
        )
        syncResult = playlistStore.synchronizeSearchPlaylist(
            id: playlistID,
            with: matchedTracks.map(\.id)
        )
    }
}
