import SwiftUI

struct PlaylistView: View {
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
        PlaylistManagementView(
            kind: .regular,
            title: "プレイリスト",
            showsLibraryLinks: true,
            searchPrompt: nil
        )
    }
}

struct WorkPlaylistView: View {
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
        PlaylistManagementView(
            kind: .work,
            title: "作業用プレイリスト",
            showsLibraryLinks: false,
            searchPrompt: "作業用プレイリストを検索"
        )
    }
}

private struct PlaylistManagementView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(LibraryStore.self) private var libraryStore
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var playlistToDelete: Playlist?
    @State private var isSelecting = false
    @State private var selection: Set<Playlist.ID> = []
    @State private var confirmsBulkDelete = false
    @State private var selectedTag: String?
    @State private var playlistToEditTags: Playlist?
    @State private var searchText = ""

    let kind: PlaylistKind
    let title: String
    let showsLibraryLinks: Bool
    let searchPrompt: String?

    private var playlists: [Playlist] {
        let playlists = playlistStore.playlists(of: kind, tagged: selectedTag)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return playlists }
        return playlists.filter { playlist in
            playlist.name.localizedStandardContains(query)
                || playlist.tags.contains(where: { $0.localizedStandardContains(query) })
        }
    }

    private var availableTags: [String] {
        PlaylistTagRules.uniqueSortedTags(playlistStore.playlists(of: kind).flatMap(\.tags))
    }

    var body: some View {
        List {
            if !availableTags.isEmpty {
                Section {
                    PlaylistTagFilterBar(tags: availableTags, selectedTag: $selectedTag)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))
                }
            }

            if showsLibraryLinks {
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
                    NavigationLink {
                        WorkPlaylistView(createsNavigationStack: false)
                    } label: {
                        Label("作業用プレイリスト", systemImage: "timer")
                    }
                }
            }

            Section(kind == .work ? "作業用プレイリスト" : "プレイリスト") {
                if playlists.isEmpty {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            kind == .work ? "作業用プレイリストはありません" : "プレイリストはありません",
                            systemImage: kind == .work ? "timer" : "music.note.list",
                            description: Text(emptyDescription)
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    ForEach(playlists) { playlist in
                        playlistRow(playlist)
                            .contextMenu {
                                Button("タグを編集", systemImage: "tag") {
                                    playlistToEditTags = playlist
                                }
                                Button("名前を変更", systemImage: "pencil") { presentRename(playlist) }
                                Button("削除", systemImage: "trash", role: .destructive) {
                                    playlistToDelete = playlist
                                }
                            }
                            .swipeActions {
                                Button("削除", systemImage: "trash", role: .destructive) {
                                    playlistToDelete = playlist
                                }
                            }
                    }
                }
            }

            if kind == .regular && !isSelecting {
                Section("ステーション") {
                    StationEntryView()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            if isSelecting {
                Section {
                    Button("選択した\(selection.count)件を削除", systemImage: "trash", role: .destructive) {
                        confirmsBulkDelete = true
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .navigationTitle(title)
        .playlistSearchable(text: $searchText, prompt: searchPrompt)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isSelecting {
                    Button("キャンセル") { stopSelecting() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if isSelecting {
                    Button("すべて選択") { selection = Set(playlists.map(\.id)) }
                } else {
                    Menu {
                        Button(newPlaylistLabel, systemImage: "plus") { presentCreatePlaylist() }
                        Button("プレイリストを選択", systemImage: "checkmark.circle") {
                            isSelecting = true
                        }
                        .disabled(playlists.isEmpty)
                    } label: {
                        Label("プレイリスト操作", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "選択したプレイリストを削除しますか？",
            isPresented: $confirmsBulkDelete,
            titleVisibility: .visible
        ) {
            Button("\(selection.count)件を削除", role: .destructive) {
                playlistStore.deletePlaylists(ids: selection)
                stopSelecting()
            }
        } message: {
            Text("音楽ファイルやライブラリの曲は削除されません。")
        }
        .navigationDestination(for: Playlist.ID.self) { playlistID in
            PlaylistDetailView(playlistID: playlistID)
        }
        .sheet(item: $playlistToEditTags) { playlist in
            PlaylistTagEditorView(playlist: playlist)
        }
        .alert(newPlaylistLabel, isPresented: $isCreatingPlaylist) {
            TextField("プレイリスト名", text: $newPlaylistName)
            Button("キャンセル", role: .cancel) {}
            Button("作成") { playlistStore.createPlaylist(named: newPlaylistName, kind: kind) }
                .disabled(trimmed(newPlaylistName).isEmpty)
        }
        .alert("プレイリスト名を変更", isPresented: renameIsPresented) {
            TextField("プレイリスト名", text: $renameText)
            Button("キャンセル", role: .cancel) { playlistToRename = nil }
            Button("保存") {
                if let playlistToRename {
                    playlistStore.renamePlaylist(id: playlistToRename.id, to: renameText)
                }
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
                if let playlistToDelete {
                    playlistStore.deletePlaylist(id: playlistToDelete.id)
                }
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
        .onChange(of: availableTags) { _, tags in
            if let selectedTag {
                self.selectedTag = tags.first {
                    PlaylistTagRules.contains([$0], tag: selectedTag)
                }
            }
        }
    }

    private var emptyDescription: String {
        if kind == .work {
            "＋ボタンから作成し、20分以上またはジャンルが作業用BGMの曲を追加できます。"
        } else {
            "＋ボタンからプレイリストを作成できます。"
        }
    }

    private var newPlaylistLabel: String {
        kind == .work ? "新規作業用プレイリスト" : "新規プレイリスト"
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { playlistToRename != nil }, set: { if !$0 { playlistToRename = nil } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { playlistToDelete != nil }, set: { if !$0 { playlistToDelete = nil } })
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { playlistStore.errorMessage != nil },
            set: { if !$0 { playlistStore.dismissError() } }
        )
    }

    private func presentCreatePlaylist() {
        newPlaylistName = ""
        isCreatingPlaylist = true
    }

    @ViewBuilder
    private func playlistRow(_ playlist: Playlist) -> some View {
        if isSelecting {
            Button {
                if !selection.insert(playlist.id).inserted {
                    selection.remove(playlist.id)
                }
            } label: {
                rowLabel(playlist, selected: selection.contains(playlist.id))
            }
        } else {
            NavigationLink(value: playlist.id) {
                rowLabel(playlist, selected: nil)
            }
        }
    }

    private func rowLabel(_ playlist: Playlist, selected: Bool?) -> some View {
        HStack {
            if let selected {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Label(playlist.name, systemImage: kind == .work ? "timer" : "music.note.list")
                    .lineLimit(1)
                PlaylistTagSummary(tags: playlist.tags)
            }
            Spacer()
            Text("\(playlistStore.tracks(for: playlist.id, in: libraryStore.tracks).count)曲")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
    }

    private func stopSelecting() {
        isSelecting = false
        selection.removeAll()
    }

    private func presentRename(_ playlist: Playlist) {
        renameText = playlist.name
        playlistToRename = playlist
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension View {
    @ViewBuilder
    func playlistSearchable(text: Binding<String>, prompt: String?) -> some View {
        if let prompt {
            searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }
}
