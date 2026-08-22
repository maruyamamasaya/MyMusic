import SwiftUI

struct GenreDisplaySettingsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var presetToDelete: GenreDisplayPreset?
    @State private var appliedSetName: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    GenreSelectionEditorView(mode: .current)
                } label: {
                    SettingsSummaryRow(
                        title: "表示するジャンル",
                        detail: "\(enabledGenreCount) / \(libraryStore.availableGenreOptions.count)",
                        systemImage: "checklist"
                    )
                }
            } header: {
                Text("現在の設定")
            } footer: {
                Text("表示しないジャンルの楽曲も削除されず、いつでも元に戻せます。")
            }

            Section {
                Button {
                    libraryStore.showAllGenres()
                    appliedSetName = "全曲表示"
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: libraryStore.areAllGenresEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(libraryStore.areAllGenresEnabled ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("全曲表示")
                                .foregroundStyle(.primary)
                            Text("すべてのジャンルを表示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(libraryStore.areAllGenresEnabled ? "選択中" : "未選択")
            }

            Section("プリセット") {
                NavigationLink {
                    GenreSelectionEditorView(mode: .newPreset)
                } label: {
                    Label("新しいプリセットを作成", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }

                if libraryStore.genreDisplayPresets.isEmpty {
                    Text("よく使うジャンルの組み合わせを保存できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(libraryStore.genreDisplayPresets) { preset in
                        presetRow(preset)
                    }
                }
            }
        }
        .navigationTitle("ジャンルごとの表示")
        .navigationBarTitleDisplayMode(.inline)
        .alert("設定しました", isPresented: appliedSetIsPresented) {
            Button("OK", role: .cancel) { appliedSetName = nil }
        } message: {
            if let appliedSetName {
                Text("「\(appliedSetName)」を設定しました。")
            }
        }
        .confirmationDialog(
            "プリセットを削除しますか？",
            isPresented: Binding(
                get: { presetToDelete != nil },
                set: { if !$0 { presetToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let presetToDelete { libraryStore.deleteGenreDisplayPreset(presetToDelete) }
                presetToDelete = nil
            }
            Button("キャンセル", role: .cancel) { presetToDelete = nil }
        }
    }

    private var enabledGenreCount: Int {
        libraryStore.availableGenreOptions.count { libraryStore.isGenreEnabled($0.id) }
    }

    private var appliedSetIsPresented: Binding<Bool> {
        Binding(
            get: { appliedSetName != nil },
            set: { if !$0 { appliedSetName = nil } }
        )
    }

    private func presetRow(_ preset: GenreDisplayPreset) -> some View {
        HStack(spacing: 12) {
            Button {
                libraryStore.applyGenreDisplayPreset(preset)
                appliedSetName = preset.name
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: libraryStore.isGenreDisplayPresetActive(preset) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(libraryStore.isGenreDisplayPresetActive(preset) ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preset.name).foregroundStyle(.primary)
                        Text("\(preset.enabledGenreNames.intersection(Set(libraryStore.availableGenreOptions.map(\.id))).count)件を表示")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {
                GenreSelectionEditorView(mode: .editPreset(preset))
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(preset.name)を編集")
        }
        .swipeActions {
            Button("削除", systemImage: "trash", role: .destructive) { presetToDelete = preset }
            NavigationLink {
                GenreSelectionEditorView(mode: .editPreset(preset))
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

private struct SettingsSummaryRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(detail).foregroundStyle(.secondary)
        }
    }
}

struct GenreSelectionEditorView: View {
    enum Mode {
        case current
        case newPreset
        case editPreset(GenreDisplayPreset)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var libraryStore
    let mode: Mode
    @State private var name = ""
    @State private var selection: Set<String> = []
    @State private var hasLoaded = false

    var body: some View {
        List {
            if needsName {
                Section("プリセット名") {
                    TextField("例：リラックス", text: $name)
                        .textInputAutocapitalization(.never)
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        selection = allIDs
                    } label: {
                        Label("すべて選択", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection == allIDs)

                    Button {
                        selection.removeAll()
                    } label: {
                        Label("すべて解除", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection.isEmpty)
                }
                .font(.subheadline.weight(.semibold))
                .controlSize(.regular)
                .padding(.vertical, 4)

                ForEach(libraryStore.availableGenreOptions) { option in
                    Button {
                        toggle(option.id)
                    } label: {
                        HStack {
                            Text(option.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selection.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.contains(option.id) ? Color.accentColor : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selection.contains(option.id) ? "表示" : "非表示")
                }
            } header: {
                Text("表示するジャンル（\(selection.count)件）")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).disabled(!canSave)
            }
        }
        .onAppear(perform: loadOnce)
    }

    private var needsName: Bool {
        if case .current = mode { return false }
        return true
    }

    private var title: String {
        switch mode {
        case .current: "表示ジャンルを編集"
        case .newPreset: "プリセットを作成"
        case .editPreset: "プリセットを編集"
        }
    }

    private var allIDs: Set<String> { Set(libraryStore.availableGenreOptions.map(\.id)) }
    private var canSave: Bool {
        !needsName || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadOnce() {
        guard !hasLoaded else { return }
        hasLoaded = true
        switch mode {
        case .current, .newPreset:
            selection = Set(libraryStore.availableGenreOptions.map(\.id).filter(libraryStore.isGenreEnabled))
        case let .editPreset(preset):
            name = preset.name
            selection = preset.enabledGenreNames.intersection(allIDs)
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func save() {
        switch mode {
        case .current:
            libraryStore.setEnabledGenres(selection)
        case .newPreset:
            libraryStore.saveGenreDisplayPreset(named: name, enabledGenreNames: selection)
        case let .editPreset(preset):
            libraryStore.updateGenreDisplayPreset(preset, name: name, enabledGenreNames: selection)
        }
        dismiss()
    }
}
