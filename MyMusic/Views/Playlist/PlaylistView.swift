import SwiftUI

struct PlaylistView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var playlistToDelete: Playlist?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        Label("お気に入り", systemImage: "heart.fill")
                    }
                }

                Section("プレイリスト") {
                    if playlistStore.playlists.isEmpty {
                        ContentUnavailableView(
                            "プレイリストはありません",
                            systemImage: "music.note.list",
                            description: Text("＋ボタンからプレイリストを作成できます。")
                        )
                    } else {
                        ForEach(playlistStore.playlists) { playlist in
                            NavigationLink(value: playlist.id) {
                                HStack {
                                    Label(playlist.name, systemImage: "music.note.list")
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(playlist.trackIDs.count)曲")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button("名前を変更", systemImage: "pencil") { presentRename(playlist) }
                                Button("削除", systemImage: "trash", role: .destructive) { playlistToDelete = playlist }
                            }
                            .swipeActions {
                                Button("削除", systemImage: "trash", role: .destructive) { playlistToDelete = playlist }
                            }
                        }
                    }
                }
            }
            .navigationTitle("プレイリスト")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("新規プレイリスト", systemImage: "plus") { presentCreatePlaylist() }
                }
            }
            .navigationDestination(for: Playlist.ID.self) { playlistID in
                PlaylistDetailView(playlistID: playlistID)
            }
            .alert("新規プレイリスト", isPresented: $isCreatingPlaylist) {
                TextField("プレイリスト名", text: $newPlaylistName)
                Button("キャンセル", role: .cancel) {}
                Button("作成") { playlistStore.createPlaylist(named: newPlaylistName) }
                    .disabled(trimmed(newPlaylistName).isEmpty)
            }
            .alert("プレイリスト名を変更", isPresented: renameIsPresented) {
                TextField("プレイリスト名", text: $renameText)
                Button("キャンセル", role: .cancel) { playlistToRename = nil }
                Button("保存") {
                    if let playlistToRename { playlistStore.renamePlaylist(id: playlistToRename.id, to: renameText) }
                    playlistToRename = nil
                }
                .disabled(trimmed(renameText).isEmpty)
            }
            .confirmationDialog(
                "「\(playlistToDelete?.name ?? "プレイリスト")」を削除しますか？",
                isPresented: deleteIsPresented,
                titleVisibility: .visible
            ) {
                Button("プレイリストを削除", role: .destructive) {
                    if let playlistToDelete { playlistStore.deletePlaylist(id: playlistToDelete.id) }
                    playlistToDelete = nil
                }
                Button("キャンセル", role: .cancel) { playlistToDelete = nil }
            } message: {
                Text("プレイリストだけを削除します。音楽ファイルは削除されません。")
            }
            .alert("プレイリストのエラー", isPresented: errorIsPresented) {
                Button("閉じる") { playlistStore.dismissError() }
            } message: {
                Text(playlistStore.errorMessage ?? "不明なエラーが発生しました。")
            }
            .task { await playlistStore.loadIfNeeded() }
        }
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { playlistToRename != nil }, set: { if !$0 { playlistToRename = nil } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { playlistToDelete != nil }, set: { if !$0 { playlistToDelete = nil } })
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { playlistStore.errorMessage != nil }, set: { if !$0 { playlistStore.dismissError() } })
    }

    private func presentCreatePlaylist() {
        newPlaylistName = ""
        isCreatingPlaylist = true
    }

    private func presentRename(_ playlist: Playlist) {
        renameText = playlist.name
        playlistToRename = playlist
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
