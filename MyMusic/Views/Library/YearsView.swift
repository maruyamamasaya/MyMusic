import SwiftUI

struct YearsView: View {
    @Environment(LibraryStore.self) private var libraryStore

    var body: some View {
        List {
            Section {
                ForEach(libraryStore.years) { group in
                    NavigationLink {
                        SongsView(
                            tracks: libraryStore.tracks(for: group.trackIDs),
                            title: title(for: group)
                        )
                    } label: {
                        HStack {
                            Label(title(for: group), systemImage: "calendar")
                            Spacer()
                            Text("\(group.trackIDs.count)曲")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("音源のタグに記録された年で分類しています。年が未設定、または無効な曲は「年不明」に表示します。")
            }
        }
        .overlay {
            if libraryStore.years.isEmpty {
                ContentUnavailableView("曲がありません", systemImage: "calendar")
            }
        }
        .themeScreen()
        .navigationTitle("年")
    }

    private func title(for group: LibraryYear) -> String {
        group.year.map { "\($0)年" } ?? "年不明"
    }
}
