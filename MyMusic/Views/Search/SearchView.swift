import SwiftUI

struct SearchView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore

    @State private var query = ""
    @State private var filter = TrackSearchFilter()
    @State private var isFilterPresented = false
    @State private var isSavingPlaylist = false
    @State private var playlistName = ""
    @State private var savedPlaylistName: String?

    private let searchService = TrackSearchService()

    private var hasSearchConditions: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || filter.hasConditions
    }

    private var results: [Track] {
        guard hasSearchConditions else { return [] }
        return searchService.search(
            tracks: libraryStore.tracks,
            query: query,
            filter: filter,
            historyEntries: playbackHistoryStore.entries
        )
    }

    private var availableGenres: [String] {
        Array(Set(libraryStore.tracks.compactMap(\.genre).filter { !$0.isEmpty }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasSearchConditions {
                    ContentUnavailableView(
                        "ライブラリを検索",
                        systemImage: "magnifyingglass",
                        description: Text("複数のキーワードや再生履歴で検索できます。")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "検索結果がありません",
                        systemImage: "magnifyingglass",
                        description: Text("別のキーワードや条件を試してください。")
                    )
                } else {
                    List {
                        Section("検索結果：\(results.count)曲") {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, track in
                                PlayableTrackRowView(track: track) {
                                    playerStore.playQueue(results, startingAt: index)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("検索")
            .searchable(text: $query, prompt: "曲、アーティスト、アルバムなど")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        playlistName = suggestedPlaylistName
                        isSavingPlaylist = true
                    } label: {
                        Label("検索結果をプレイリストに保存", systemImage: "text.badge.plus")
                    }
                    .disabled(results.isEmpty)

                    Button {
                        isFilterPresented = true
                    } label: {
                        Label(
                            "検索フィルター",
                            systemImage: filter.hasConditions
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityValue(
                        filter.hasConditions ? "\(filter.activeConditionCount)件の条件を適用中" : "条件なし"
                    )
                }
            }
            .sheet(isPresented: $isFilterPresented) {
                SearchFilterView(filter: $filter, availableGenres: availableGenres)
            }
            .alert("検索結果をプレイリストに保存", isPresented: $isSavingPlaylist) {
                TextField("プレイリスト名", text: $playlistName)
                Button("キャンセル", role: .cancel) {}
                Button("保存") { saveResultsAsPlaylist() }
                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("現在の検索結果 \(results.count)曲を新しいプレイリストに保存します。")
            }
            .alert("保存しました", isPresented: savedPlaylistIsPresented) {
                Button("閉じる", role: .cancel) { savedPlaylistName = nil }
            } message: {
                Text("「\(savedPlaylistName ?? "")」に検索結果を保存しました。")
            }
        }
    }

    private var suggestedPlaylistName: String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? "検索フィルターの結果" : "検索：\(trimmedQuery)"
    }

    private var savedPlaylistIsPresented: Binding<Bool> {
        Binding(get: { savedPlaylistName != nil }, set: { if !$0 { savedPlaylistName = nil } })
    }

    private func saveResultsAsPlaylist() {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !results.isEmpty else { return }
        let definition = PlaylistSearchDefinition(query: query, filter: filter)
        guard playlistStore.importPlaylist(
            named: name,
            trackIDs: results.map(\.id),
            searchDefinition: definition
        ) != nil else { return }
        savedPlaylistName = name
    }
}

private struct SearchFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: TrackSearchFilter
    @State private var draft: TrackSearchFilter
    let availableGenres: [String]

    init(filter: Binding<TrackSearchFilter>, availableGenres: [String]) {
        _filter = filter
        _draft = State(initialValue: filter.wrappedValue)
        self.availableGenres = availableGenres
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("キーワード") {
                    matchModePicker("キーワードの一致方法", selection: $draft.keywordMatchMode)
                    Text(draft.keywordMatchMode == .and
                         ? "すべてのキーワードを含む曲を表示します。"
                         : "いずれかのキーワードを含む曲を表示します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if draft.conditions.isEmpty {
                        Text("条件はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        matchModePicker("条件の組み合わせ", selection: $draft.conditionMatchMode)
                        ForEach($draft.conditions) { $condition in
                            conditionRow($condition)
                        }
                        .onDelete { draft.conditions.remove(atOffsets: $0) }
                    }

                    Menu("条件を追加", systemImage: "plus.circle") {
                        ForEach(TrackSearchConditionKind.allCases) { kind in
                            Button(kind.title) {
                                draft.conditions.append(
                                    TrackSearchCondition(
                                        kind: kind,
                                        textValue: kind == .genre ? availableGenres.first : nil
                                    )
                                )
                            }
                            .disabled(kind == .genre && availableGenres.isEmpty)
                        }
                    }
                } header: {
                    Text("複合条件")
                } footer: {
                    if !draft.conditions.isEmpty {
                        Text(draft.conditionMatchMode == .and
                             ? "追加したすべての条件に一致する曲を表示します。"
                             : "追加したいずれかの条件に一致する曲を表示します。")
                    }
                }
            }
            .navigationTitle("検索フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") { filter = draft; dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("フィルターをリセット", role: .destructive) {
                        draft.conditions.removeAll()
                    }
                    .disabled(draft.conditions.isEmpty)
                }
            }
        }
    }

    private func matchModePicker(_ title: String, selection: Binding<SearchMatchMode>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SearchMatchMode.allCases) { mode in Text(mode.title).tag(mode) }
        }
        .pickerStyle(.segmented)
    }

    private func conditionRow(_ condition: Binding<TrackSearchCondition>) -> some View {
        HStack {
            Picker("条件", selection: condition.kind) {
                ForEach(TrackSearchConditionKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()

            if condition.wrappedValue.kind.needsValue {
                TextField("回数", value: condition.value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 52, maxWidth: 72)
                Text("回")
                    .foregroundStyle(.secondary)
            } else if condition.wrappedValue.kind.needsTextValue {
                Picker("ジャンル", selection: condition.textValue) {
                    ForEach(genres(for: condition.wrappedValue), id: \.self) { genre in
                        Text(genre).tag(Optional(genre))
                    }
                }
                .labelsHidden()
            }
        }
    }

    private func genres(for condition: TrackSearchCondition) -> [String] {
        guard let selected = condition.textValue,
              !selected.isEmpty,
              !availableGenres.contains(selected) else { return availableGenres }
        return [selected] + availableGenres
    }
}
