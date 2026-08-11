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
                        title: "Queue Is Empty",
                        message: "Choose a song to start a playback queue."
                    )
                } else {
                    List {
                        Section("Up Next") {
                            ForEach(Array(playerStore.queue.enumerated()), id: \.element.id) { index, track in
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
                                            Text("Playing")
                                                .font(.caption)
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
