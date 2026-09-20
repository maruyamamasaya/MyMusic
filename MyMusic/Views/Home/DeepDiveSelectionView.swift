import SwiftUI

struct DeepDiveSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: DeepDiveKind?

    let options: [DeepDiveKind: [DeepDiveOption]]
    let onPlay: ([Track]) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let selectedKind {
                    let choices = options[selectedKind] ?? []
                    if choices.isEmpty {
                        ContentUnavailableView(
                            "候補がありません",
                            systemImage: selectedKind.systemImage,
                            description: Text("最近よく聴く\(selectedKind.title)に、まだあまり聴いていない曲が見つかりませんでした。")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(choices) { choice in
                                Button {
                                    dismiss()
                                    onPlay(choice.tracks)
                                } label: {
                                    HStack(spacing: 12) {
                                        AlbumArtworkView(artworkIdentifier: choice.artworkIdentifier)
                                            .frame(width: 52, height: 52)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(choice.title).font(.headline).foregroundStyle(.primary)
                                            if let detail = choice.detail {
                                                Text(detail).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Text("未聴・低再生 \(choice.tracks.count)曲 · 最近\(choice.recentPlayCount)回")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: "play.fill").foregroundStyle(.tint)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("\(choice.title)の低再生曲を再生")
                            }
                        } header: {
                            Text("最近よく聴く\(selectedKind.title)")
                        }
                    }
                } else {
                    Section {
                        ForEach(DeepDiveKind.allCases) { kind in
                            Button {
                                selectedKind = kind
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: kind.systemImage)
                                        .font(.title3)
                                        .frame(width: 32)
                                        .foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(kind.title).font(.headline).foregroundStyle(.primary)
                                        Text("候補 \(options[kind]?.count ?? 0)件")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("どちらから探しますか？")
                    } footer: {
                        Text("最近よく聴くArtistやAlbumから、再生回数の少ない曲を探します。")
                    }
                }
            }
            .navigationTitle(selectedKind?.title ?? "Deep Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedKind != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("戻る", systemImage: "chevron.left") { selectedKind = nil }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .themeScreen()
        .presentationDetents([.medium, .large])
    }
}
