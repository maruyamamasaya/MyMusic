import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    let track: Track

    @State private var isCreatingPlaylist = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("新規プレイリスト", systemImage: "plus") {
                        isCreatingPlaylist = true
                    }
                }

                Section("プレイリストを選択") {
                    if playlistStore.playlists.isEmpty {
                        Text("プレイリストはありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(playlistStore.playlists) { playlist in
                            let alreadyAdded = playlistStore.contains(track.id, in: playlist.id)
                            Button {
                                playlistStore.toggleTrack(track, in: playlist.id)
                            } label: {
                                HStack {
                                    Text(playlist.name).foregroundStyle(.primary)
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
            .navigationTitle("プレイリストに追加")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isCreatingPlaylist) {
                CreatePlaylistForTrackView(track: track)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
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
        .navigationTitle("新規プレイリスト")
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
        guard let playlistID = playlistStore.createPlaylist(named: trimmedName) else { return }
        playlistStore.addTrack(track, to: playlistID)
        dismiss()
    }
}
