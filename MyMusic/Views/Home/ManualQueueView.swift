import SwiftUI

struct ManualQueueView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(PlayerStore.self) private var playerStore
    @State private var selection = ManualQueueStore()

    private func queueButton(_ track: Track, title: String, symbol: String, playNext: Bool) -> some View {
        Button {
            selection.select(track, player: playerStore, playNext: playNext)
        } label: {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(track.title)を\(title)")
        .help(title)
    }

    var body: some View {
        List {
            if selection.hasStarted {
                Section("いまのキュー") {
                    if let track = playerStore.currentTrack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(playerStore.isPlaying ? "再生中" : "停止中")
                                .font(.caption).foregroundStyle(.secondary)
                            TrackRowView(track: track)
                        }
                    }
                }
                Section {
                    ForEach(selection.upcomingTracks(player: playerStore)) { track in
                        TrackRowView(track: track)
                    }
                    .onDelete { offsets in
                        selection.removeUpcoming(atOffsets: offsets, player: playerStore)
                    }
                    .onMove { source, destination in
                        selection.moveUpcoming(fromOffsets: source, toOffset: destination, player: playerStore)
                    }
                } header: {
                    Text("次に待っている曲 · \(selection.upcomingTracks(player: playerStore).count)曲")
                } footer: {
                    Text("左にスワイプして取り消し。「編集」で再生順を並べ替えられます。")
                }
            }
            Section {
                if selection.candidates.isEmpty {
                    ContentUnavailableView("候補の曲がありません", systemImage: "music.note",
                                           description: Text("ライブラリとチューニングの設定を確認してください。"))
                }
                ForEach(selection.candidates) { track in
                    let added = selection.selectedIDs.contains(track.id)
                    HStack(spacing: 0) {
                        Button {
                            selection.select(track, player: playerStore)
                        } label: {
                            TrackRowView(track: track, showsDuration: false)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(added)
                        .accessibilityHint(selection.hasStarted ? "キューの最後に追加" : "現在のキューを置き換えて再生")

                        if added {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44)
                                .accessibilityLabel("追加済み")
                        } else if selection.hasStarted {
                            queueButton(track, title: "次に再生", symbol: "text.line.first.and.arrowtriangle.forward", playNext: true)
                            queueButton(track, title: "最後に追加", symbol: "text.line.last.and.arrowtriangle.forward", playNext: false)
                        }
                    }
                }
            } header: {
                Text(selection.hasStarted ? "次に聴く曲を選択" : "最初に再生する曲を選択")
            } footer: {
                Text(selection.hasStarted
                     ? "右のアイコンで次に再生するか、最後に追加するかを選べます。曲名のタップは最後に追加します。"
                     : "最初の1曲を選ぶと、現在のキューをリセットして再生します。")
            }
        }
        .themeScreen()
        .navigationTitle("次に再生する")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selection.hasStarted {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("候補を入れ替える", systemImage: "arrow.clockwise") {
                    selection.refresh(from: libraryStore.tracks, history: historyStore)
                }
            }
        }
        .onAppear {
            selection.resetSelection()
            selection.refresh(from: libraryStore.tracks, history: historyStore)
        }
        .onDisappear { selection.resetSelection() }
    }
}
