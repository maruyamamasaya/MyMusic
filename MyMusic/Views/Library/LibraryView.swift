import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var isFolderImporterPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("音楽ライブラリ") {
                    if libraryStore.hasLibraryFolder {
                        Label(libraryStore.selectedFolderName ?? "音楽フォルダ", systemImage: "folder")
                    } else {
                        ContentUnavailableView(
                            "音楽フォルダが未選択です",
                            systemImage: "folder.badge.questionmark",
                            description: Text("“ファイル”またはiCloud Driveから、読み込みたい音楽フォルダを選択してください。")
                        )
                    }

                    if libraryStore.isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView()
                            Text("音楽ライブラリを読み込み中…")
                            Text("現在 \(libraryStore.scanProgress) 曲")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if libraryStore.hasLibraryFolder {
                    Section("ライブラリ") {
                        NavigationLink(value: LibraryDestination.songs) { countRow("曲", systemImage: "music.note", count: libraryStore.tracks.count) }
                        NavigationLink(value: LibraryDestination.albums) { countRow("アルバム", systemImage: "square.stack", count: libraryStore.albums.count) }
                        NavigationLink(value: LibraryDestination.artists) { countRow("アーティスト", systemImage: "music.mic", count: libraryStore.artists.count) }
                    }

                    Section {
                        Button("ライブラリを再読み込み", systemImage: "arrow.clockwise") {
                            Task { await libraryStore.rescan() }
                        }
                        .disabled(libraryStore.isLoading)
                        Button("音楽フォルダを変更", systemImage: "folder.badge.gearshape") {
                            isFolderImporterPresented = true
                        }
                        .disabled(libraryStore.isLoading)
                    }
                } else {
                    Button("音楽フォルダを選択", systemImage: "folder.badge.plus") {
                        isFolderImporterPresented = true
                    }
                }
            }
            .navigationTitle("ライブラリ")
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .songs: SongsView(tracks: libraryStore.tracks)
                case .albums: AlbumsView(albums: libraryStore.albums)
                case .artists: ArtistsView(artists: libraryStore.artists)
                }
            }
            .fileImporter(
                isPresented: $isFolderImporterPresented,
                allowedContentTypes: [UTType.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let folderURL = urls.first else { return }
                    Task { await libraryStore.selectFolder(folderURL) }
                case let .failure(error):
                    libraryStore.reportFolderImportFailure(error)
                }
            }
            .alert("音楽ライブラリのエラー", isPresented: errorIsPresented) {
                Button("閉じる") { libraryStore.dismissError() }
            } message: {
                Text(libraryStore.errorMessage ?? "不明なエラーが発生しました。")
            }
            .task { await libraryStore.restoreAndLoadIfNeeded() }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { libraryStore.errorMessage != nil },
            set: { if !$0 { libraryStore.dismissError() } }
        )
    }

    private func countRow(_ title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(count, format: .number).foregroundStyle(.secondary)
        }
    }
}

private enum LibraryDestination: Hashable {
    case songs, albums, artists
}
