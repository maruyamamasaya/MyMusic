import SwiftUI

struct PlaylistTagManagementView: View {
    @Environment(PlaylistStore.self) private var playlistStore

    @State private var tagToRename: String?
    @State private var renameText = ""
    @State private var tagToDelete: String?

    var body: some View {
        List {
            if playlistStore.allTags.isEmpty {
                ContentUnavailableView(
                    "タグはありません",
                    systemImage: "tag",
                    description: Text("プレイリストのタグ編集から追加したタグがここに表示されます。")
                )
            } else {
                Section {
                    ForEach(playlistStore.allTags, id: \.self) { tag in
                        NavigationLink {
                            PlaylistTagAssignmentView(tag: tag)
                        } label: {
                            HStack {
                                Label(tag, systemImage: "tag")
                                Spacer()
                                Text("\(usageCount(for: tag))件")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("名前を変更", systemImage: "pencil") { presentRename(tag) }
                            Button("削除", systemImage: "trash", role: .destructive) {
                                tagToDelete = tag
                            }
                        }
                        .swipeActions {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                tagToDelete = tag
                            }
                            Button("名前変更", systemImage: "pencil") { presentRename(tag) }
                                .tint(.blue)
                        }
                    }
                } footer: {
                    Text("タグを選ぶと、複数のプレイリストへの設定をまとめて変更できます。")
                }
            }
        }
        .themeScreen()
        .navigationTitle("タグ管理")
        .alert("タグ名を変更", isPresented: renameIsPresented) {
            TextField("タグ名", text: $renameText)
            Button("キャンセル", role: .cancel) { tagToRename = nil }
            Button("保存") {
                if let tagToRename {
                    playlistStore.renameTag(tagToRename, to: renameText)
                }
                tagToRename = nil
            }
            .disabled(PlaylistTagRules.normalizedTag(renameText) == nil)
        }
        .confirmationDialog(
            "「\(tagToDelete ?? "タグ")」を削除しますか？",
            isPresented: deleteIsPresented,
            titleVisibility: .visible
        ) {
            Button("すべてのプレイリストから削除", role: .destructive) {
                if let tagToDelete { playlistStore.deleteTag(tagToDelete) }
                tagToDelete = nil
            }
            Button("キャンセル", role: .cancel) { tagToDelete = nil }
        } message: {
            Text("プレイリストと曲は削除されません。")
        }
    }

    private func usageCount(for tag: String) -> Int {
        playlistStore.playlists.filter { PlaylistTagRules.contains($0.tags, tag: tag) }.count
    }

    private func presentRename(_ tag: String) {
        tagToRename = tag
        renameText = tag
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { tagToRename != nil }, set: { if !$0 { tagToRename = nil } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { tagToDelete != nil }, set: { if !$0 { tagToDelete = nil } })
    }
}

private struct PlaylistTagAssignmentView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    let tag: String

    var body: some View {
        List {
            playlistSection(title: "プレイリスト", kind: .regular)
            playlistSection(title: "作業用プレイリスト", kind: .work)
        }
        .themeScreen()
        .navigationTitle(tag)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func playlistSection(title: String, kind: PlaylistKind) -> some View {
        let playlists = playlistStore.playlists(of: kind)
        if !playlists.isEmpty {
            Section(title) {
                ForEach(playlists) { playlist in
                    let isAssigned = PlaylistTagRules.contains(playlist.tags, tag: tag)
                    Button {
                        playlistStore.setTag(tag, isAssigned: !isAssigned, for: playlist.id)
                    } label: {
                        HStack {
                            Text(playlist.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isAssigned {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
    }
}
