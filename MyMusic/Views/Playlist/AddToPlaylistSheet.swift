import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    let track: Track

    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("新規プレイリスト", systemImage: "plus") {
                        newPlaylistName = ""
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .alert("新規プレイリスト", isPresented: $isCreatingPlaylist) {
                TextField("プレイリスト名", text: $newPlaylistName)
                Button("キャンセル", role: .cancel) {}
                Button("作成") {
                    if let playlistID = playlistStore.createPlaylist(named: newPlaylistName) {
                        playlistStore.addTrack(track, to: playlistID)
                    }
                }
                .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
