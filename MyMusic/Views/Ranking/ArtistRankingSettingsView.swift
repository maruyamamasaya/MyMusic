import SwiftUI

struct ArtistRankingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ArtistRankingStore
    let tracks: [Track]
    @State private var draft: ArtistRankingSettings

    init(store: ArtistRankingStore, tracks: [Track]) {
        self.store = store
        self.tracks = tracks
        _draft = State(initialValue: store.settings)
    }

    private var genres: [String] {
        let current = tracks.filter(\.isEligibleForRegularPlayback).reduce(into: Set<String>()) {
            $0.formUnion($1.normalizedGenreNames)
        }
        return current.union(draft.instrumental.genres).union(draft.vocal.genres)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("ジャンルごとに部門を選びます。両部門への登録も可能です。未選択の部門には曲を表示しません。")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("このiPhoneに保存します。HomeStereoの部門設定とは独立しています。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("ジャンル") {
                    ForEach(genres, id: \.self) { genre in
                        VStack(alignment: .leading) {
                            Text(genre)
                            HStack {
                                genreToggle(genre, division: .instrumental)
                                genreToggle(genre, division: .vocal)
                            }
                        }
                    }
                }
                Section("ジャンル未設定") {
                    ForEach(ArtistRankingDivision.allCases, id: \.self) { division in
                        Toggle(division.title, isOn: Binding(
                            get: { draft[division].includesUnassigned },
                            set: { draft[division].includesUnassigned = $0 }
                        ))
                    }
                }
                if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("ランキング部門")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { if store.save(draft) { dismiss() } }
                }
            }
        }
    }

    private func genreToggle(_ genre: String, division: ArtistRankingDivision) -> some View {
        let selected = draft[division].genres.contains(genre)
        return Button {
            if selected { draft[division].genres.remove(genre) }
            else { draft[division].genres.insert(genre) }
        } label: {
            Label(division.title, systemImage: selected ? "checkmark.square.fill" : "square")
                .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
        .accessibilityLabel("\(genre)、\(division.title)")
        .accessibilityValue(selected ? "選択中" : "未選択")
    }
}
