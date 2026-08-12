import SwiftUI

struct QueueView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if playerStore.queue.isEmpty {
                    EmptyStateView(
                        icon: "text.line.last.and.arrowtriangle.forward",
                        title: "再生キューは空です",
                        message: "曲を選択すると再生キューが作成されます。"
                    )
                } else {
                    List {
                        Section("次に再生") {
                            ForEach(playerStore.playbackOrder, id: \.self) { index in
                                let track = playerStore.queue[index]
                                Button {
                                    playerStore.playQueueItem(at: index)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: index == playerStore.currentIndex ? "speaker.wave.2.fill" : "music.note")
                                            .foregroundStyle(index == playerStore.currentIndex ? Color.accentColor : Color.secondary)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title).lineLimit(1)
                                            Text(track.artistName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if index == playerStore.currentIndex {
                                            Text("再生中")
                                                .font(.caption)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .deleteDisabled(index == playerStore.currentIndex)
                            }
                            .onDelete(perform: playerStore.removeQueueItems)
                            .onMove(perform: playerStore.moveQueueItems)
                        }
                    }
                }
            }
            .navigationTitle("再生キュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
