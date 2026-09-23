import SwiftUI

struct GenreDisplaySettingsView: View {
    @Environment(\.appTheme) private var appTheme
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
                        detail: "\(enabledGenreCount) / \(libraryStore.selectableGenreOptions.count)",
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
                            .foregroundStyle(libraryStore.areAllGenresEnabled ? ThemePalette.resolve(appTheme).accent : .secondary)
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

            Section {
                NavigationLink {
                    GenreSelectionEditorView(mode: .newPreset)
                } label: {
                    Label("新しいプリセットを作成", systemImage: "plus.circle.fill")
                        .foregroundStyle(ThemePalette.resolve(appTheme).accent)
                }

                if libraryStore.genreDisplayPresets.isEmpty {
                    Text("よく使うジャンルの組み合わせを保存できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(libraryStore.genreDisplayPresets) { preset in
                        presetRow(preset)
                    }
                    .onMove(perform: libraryStore.moveGenreDisplayPresets)
                }
            } header: {
                Text("プリセット")
            } footer: {
                if libraryStore.genreDisplayPresets.count > 1 {
                    Text("右上の「編集」を押すと、ドラッグして表示順を変更できます。")
                }
            }
        }
        .themeScreen()
        .navigationTitle("ジャンルごとの表示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .disabled(libraryStore.genreDisplayPresets.count < 2)
            }
        }
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
        libraryStore.selectableGenreOptions.count { libraryStore.isGenreEnabled($0.id) }
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
                        .foregroundStyle(libraryStore.isGenreDisplayPresetActive(preset) ? ThemePalette.resolve(appTheme).accent : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preset.name).foregroundStyle(.primary)
                        Text("\(libraryStore.enabledGenreCount(for: preset))件を表示")
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
    @Environment(\.appTheme) private var appTheme
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

            if !libraryStore.fixedGenreOptions.isEmpty {
                Section {
                    ForEach(libraryStore.fixedGenreOptions) { option in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name)
                                Text("専用ライブラリとして常に表示")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "lock.circle.fill")
                                .font(.title3)
                                .foregroundStyle(ThemePalette.resolve(appTheme).accent)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue("常に表示")
                    }
                } header: {
                    Text("固定の専用分類")
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
                        selection = fixedIDs
                    } label: {
                        Label("すべて解除", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selection == fixedIDs)
                }
                .font(.subheadline.weight(.semibold))
                .controlSize(.regular)
                .padding(.vertical, 4)

                ForEach(libraryStore.selectableGenreOptions) { option in
                    Button {
                        toggle(option.id)
                    } label: {
                        HStack {
                            Text(option.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selection.contains(option.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(
                                    selection.contains(option.id) ? ThemePalette.resolve(appTheme).accent : .secondary
                                )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(selection.contains(option.id) ? "表示" : "非表示")
                }
            } header: {
                Text("表示するジャンル（\(selectedSelectableCount)件）")
            }
        }
        .themeScreen()
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
    private var selectableIDs: Set<String> { Set(libraryStore.selectableGenreOptions.map(\.id)) }
    private var fixedIDs: Set<String> { Set(allIDs.filter(libraryStore.isGenreAlwaysEnabled)) }
    private var selectedSelectableCount: Int { selection.intersection(selectableIDs).count }
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
            selection = preset.enabledGenreNames.intersection(allIDs).union(fixedIDs)
        }
    }

    private func toggle(_ id: String) {
        guard !libraryStore.isGenreAlwaysEnabled(id) else { return }
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
