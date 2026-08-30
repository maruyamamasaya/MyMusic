import SwiftUI

struct PlaylistTagEditorView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss

    let playlistID: Playlist.ID

    @State private var draftTags: [String]
    @State private var newTag = ""
    @State private var validationMessage: String?

    init(playlist: Playlist) {
        playlistID = playlist.id
        _draftTags = State(initialValue: playlist.tags)
    }

    private var suggestions: [String] {
        playlistStore.allTags.filter { !PlaylistTagRules.contains(draftTags, tag: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if draftTags.isEmpty {
                        Text("タグは設定されていません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draftTags, id: \.self) { tag in
                            HStack {
                                Label(tag, systemImage: "tag")
                                Spacer()
                                Button("削除", systemImage: "xmark.circle.fill") {
                                    remove(tag)
                                }
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("\(tag)を削除")
                            }
                        }
                    }
                } header: {
                    Text("設定中")
                } footer: {
                    Text("タグの変更はプレイリスト内の曲や再生中のキューに影響しません。")
                }

                Section {
                    HStack {
                        TextField("新しいタグ", text: $newTag)
                            .submitLabel(.done)
                            .onSubmit(addNewTag)
                        Button("追加", action: addNewTag)
                            .disabled(!canAddNewTag)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("タグを追加")
                } footer: {
                    Text("1つのプレイリストに最大\(PlaylistTagRules.maximumTagCount)件、1件は\(PlaylistTagRules.maximumTagLength)文字までです。")
                }

                if !suggestions.isEmpty {
                    Section("既存のタグ") {
                        ForEach(suggestions, id: \.self) { tag in
                            Button {
                                add(tag)
                            } label: {
                                Label(tag, systemImage: "plus.circle")
                            }
                            .disabled(draftTags.count >= PlaylistTagRules.maximumTagCount)
                        }
                    }
                }
            }
            .navigationTitle("タグを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        playlistStore.setTags(draftTags, for: playlistID)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canAddNewTag: Bool {
        guard draftTags.count < PlaylistTagRules.maximumTagCount,
              let normalized = PlaylistTagRules.normalizedTag(newTag) else { return false }
        return !PlaylistTagRules.contains(draftTags, tag: normalized)
    }

    private func addNewTag() {
        guard draftTags.count < PlaylistTagRules.maximumTagCount else {
            validationMessage = "タグは最大\(PlaylistTagRules.maximumTagCount)件です。"
            return
        }
        guard let normalized = PlaylistTagRules.normalizedTag(newTag) else {
            validationMessage = "空白以外の\(PlaylistTagRules.maximumTagLength)文字以内で入力してください。"
            return
        }
        guard !PlaylistTagRules.contains(draftTags, tag: normalized) else {
            validationMessage = "同じタグがすでに設定されています。"
            return
        }
        add(normalized)
        newTag = ""
    }

    private func add(_ tag: String) {
        draftTags = PlaylistTagRules.normalizedTags(draftTags + [tag])
        validationMessage = nil
    }

    private func remove(_ tag: String) {
        let key = PlaylistTagRules.comparisonKey(for: tag)
        draftTags.removeAll { PlaylistTagRules.comparisonKey(for: $0) == key }
        validationMessage = nil
    }
}
