import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    let track: Track

    @State private var isCreatingPlaylist = false
    @State private var selectedTag: String?
    @State private var searchText = ""

    private var playlistKind: PlaylistKind {
        track.isEligibleForWorkPlayback ? .work : .regular
    }

    private var compatiblePlaylists: [Playlist] {
        playlistStore.playlists(compatibleWith: track, tagged: selectedTag).filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var availableTags: [String] {
        PlaylistTagRules.uniqueSortedTags(playlistStore.playlists(compatibleWith: track).flatMap(\.tags))
    }

    var body: some View {
        NavigationStack {
            List {
                if !availableTags.isEmpty {
                    Section {
                        PlaylistTagFilterBar(tags: availableTags, selectedTag: $selectedTag)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))
                    }
                }

                Section {
                    Button(
                        playlistKind == .work ? "新規作業用プレイリスト" : "新規プレイリスト",
                        systemImage: "plus"
                    ) {
                        isCreatingPlaylist = true
                    }
                }

                Section(playlistKind == .work ? "作業用プレイリストを選択" : "プレイリストを選択") {
                    if compatiblePlaylists.isEmpty {
                        Text("プレイリストはありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(compatiblePlaylists) { playlist in
                            let alreadyAdded = playlistStore.contains(track.id, in: playlist.id)
                            Button {
                                playlistStore.toggleTrack(track, in: playlist.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(playlist.name).foregroundStyle(.primary)
                                        PlaylistTagSummary(tags: playlist.tags)
                                    }
                                    Spacer()
                                    if alreadyAdded {
                                        Label("追加済み・タップで削除", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .accessibilityHint(alreadyAdded ? "このプレイリストから曲を削除します" : "このプレイリストへ曲を追加します")
                        }
                    }
                }
            }
            .navigationTitle(playlistKind == .work ? "作業用プレイリストに追加" : "プレイリストに追加")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "プレイリストを検索")
            .navigationDestination(isPresented: $isCreatingPlaylist) {
                CreatePlaylistForTrackView(track: track, kind: playlistKind)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .onChange(of: availableTags) { _, tags in
                if let selectedTag {
                    self.selectedTag = tags.first {
                        PlaylistTagRules.contains([$0], tag: selectedTag)
                    }
                }
            }
        }
    }
}

private struct CreatePlaylistForTrackView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    let track: Track
    let kind: PlaylistKind

    var body: some View {
        Form {
            Section("プレイリスト名") {
                TextField("名前", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(createPlaylist)
            }
        }
        .navigationTitle(kind == .work ? "新規作業用プレイリスト" : "新規プレイリスト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("作成", action: createPlaylist)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .task { isNameFocused = true }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createPlaylist() {
        guard let playlistID = playlistStore.createPlaylist(named: trimmedName, kind: kind) else { return }
        playlistStore.addTrack(track, to: playlistID)
        dismiss()
    }
}
