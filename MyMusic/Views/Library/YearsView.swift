import SwiftUI

struct YearsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(libraryStore.years) { group in
                        let tracks = libraryStore.tracks(for: group.trackIDs)
                        NavigationLink {
                            SongsView(
                                tracks: tracks,
                                title: title(for: group)
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                AlbumArtworkView(
                                    artworkIdentifier: tracks.lazy.compactMap(\.artworkIdentifier).first
                                )
                                .accessibilityHidden(true)
                                Text(title(for: group))
                                    .font(.headline)
                                Text("\(group.trackIDs.count)曲")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
                if !libraryStore.years.isEmpty {
                    Text("音源のタグに記録された年で分類しています。年が未設定、または無効な曲は「年不明」に表示します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
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
