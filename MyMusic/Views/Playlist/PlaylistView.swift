import SwiftUI

struct PlaylistView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var playlistToDelete: Playlist?
    @State private var isSelecting = false
    @State private var selection: Set<Playlist.ID> = []
    @State private var confirmsBulkDelete = false
    private let createsNavigationStack: Bool

    init(createsNavigationStack: Bool = true) {
        self.createsNavigationStack = createsNavigationStack
    }

    @ViewBuilder
    var body: some View {
        if createsNavigationStack {
            NavigationStack { content }
        } else {
            content
        }
    }

    private var content: some View {
        List {
                Section {
                    NavigationLink {
                        FavoritesView()
                    } label: {
                        Label("お気に入り", systemImage: "heart.fill")
                    }
                    NavigationLink {
                        FavoriteAlbumsView()
                    } label: {
                        Label("お気に入りのアルバム", systemImage: "square.stack.fill")
                    }
                    NavigationLink {
                        FavoriteArtistsView()
                    } label: {
                        Label("お気に入りのアーティスト", systemImage: "person.2.fill")
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
                            playlistRow(playlist)
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
                if isSelecting {
                    Section {
                        Button("選択した\(selection.count)件を削除", systemImage: "trash", role: .destructive) {
                            confirmsBulkDelete = true
                        }.disabled(selection.isEmpty)
                    }
                }
        }
            .navigationTitle("プレイリスト")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isSelecting { Button("キャンセル") { stopSelecting() } }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSelecting {
                        Button("すべて選択") { selection = Set(playlistStore.playlists.map(\.id)) }
                    } else {
                        Menu {
                            Button("新規プレイリスト", systemImage: "plus") { presentCreatePlaylist() }
                            Button("プレイリストを選択", systemImage: "checkmark.circle") { isSelecting = true }
                        } label: { Label("プレイリスト操作", systemImage: "ellipsis.circle") }
                    }
                }
            }
            .confirmationDialog("選択したプレイリストを削除しますか？", isPresented: $confirmsBulkDelete, titleVisibility: .visible) {
                Button("\(selection.count)件を削除", role: .destructive) {
                    playlistStore.deletePlaylists(ids: selection); stopSelecting()
                }
            } message: { Text("音楽ファイルやライブラリの曲は削除されません。") }
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
            .onDisappear {
                if isSelecting { stopSelecting() }
                confirmsBulkDelete = false
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

    @ViewBuilder private func playlistRow(_ playlist: Playlist) -> some View {
        if isSelecting {
            Button {
                if !selection.insert(playlist.id).inserted { selection.remove(playlist.id) }
            } label: { rowLabel(playlist, selected: selection.contains(playlist.id)) }
        } else {
            NavigationLink(value: playlist.id) { rowLabel(playlist, selected: nil) }
        }
    }

    private func rowLabel(_ playlist: Playlist, selected: Bool?) -> some View {
        HStack {
            if let selected { Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.accentColor : .secondary) }
            Label(playlist.name, systemImage: "music.note.list").lineLimit(1)
            Spacer()
            Text("\(playlist.trackIDs.count)曲").font(.caption).foregroundStyle(.secondary)
        }.foregroundStyle(.primary)
    }

    private func stopSelecting() { isSelecting = false; selection.removeAll() }

    private func presentRename(_ playlist: Playlist) {
        renameText = playlist.name
        playlistToRename = playlist
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
