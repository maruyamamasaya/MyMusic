import SwiftUI

struct PlaylistDetailView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    let playlistID: Playlist.ID

    @State private var isEditingPlaylist = false
    @State private var selectedTracks: Set<Track.ID> = []
    @State private var isAddingSongs = false
    @State private var isRenaming = false
    @State private var renameText = ""

    private let exporter = MusicDataExportService()
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
        .environment(\.editMode, .constant(isEditingPlaylist ? .active : .inactive))
        .navigationTitle(playlist?.name ?? "プレイリスト")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditingPlaylist ? "完了" : "編集") {
                    isEditingPlaylist.toggle(); if !isEditingPlaylist { selectedTracks.removeAll() }
                }.disabled(playlist == nil)
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
    }

    private var controls: some View {
        Section {
            if isEditingPlaylist {
                Button("曲を追加", systemImage: "plus") { isAddingSongs = true }
                Button("名前を変更", systemImage: "pencil") {
                    renameText = playlist?.name ?? ""; isRenaming = true
                }
            } else {
                HStack(spacing: 12) {
                    Button("再生", systemImage: "play.fill") { play(shuffled: false) }.buttonStyle(.borderedProminent).disabled(tracks.isEmpty)
                    Button("シャッフル", systemImage: "shuffle") { play(shuffled: true) }.buttonStyle(.bordered).disabled(tracks.isEmpty)
                }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
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
}
