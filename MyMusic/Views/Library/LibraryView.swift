import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var isFolderImporterPresented = false
    @State private var isGenreSettingsExpanded = false
    @State private var isPresetNamePresented = false
    @State private var presetName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("音楽ライブラリ") {
                    if libraryStore.hasLibraryFolder {
                        ForEach(libraryStore.libraryFolders) { folder in
                            HStack {
                                Label(folder.name, systemImage: "folder")
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await libraryStore.removeFolder(folder) }
                                } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(folder.name)を解除")
                            }
                        }
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
                        NavigationLink(value: LibraryDestination.genres) { countRow("ジャンル", systemImage: "guitars", count: libraryStore.genres.count) }
                        NavigationLink(value: LibraryDestination.composers) { countRow("作曲者", systemImage: "music.quarternote.3", count: libraryStore.composers.count) }
                    }

                    if !libraryStore.availableGenreOptions.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isGenreSettingsExpanded) {
                                if !libraryStore.genreDisplayPresets.isEmpty {
                                    ForEach(libraryStore.genreDisplayPresets) { preset in
                                        presetRow(preset)
                                    }
                                    Divider()
                                }

                                Button("現在の設定をプリセットに保存", systemImage: "plus.circle") {
                                    presetName = ""
                                    isPresetNamePresented = true
                                }

                                ForEach(libraryStore.availableGenreOptions) { option in
                                    Toggle(option.name, isOn: genreBinding(for: option.id))
                                }
                            } label: {
                                Label("ジャンルごとの表示", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        } footer: {
                            Text("OFFにしたジャンルはライブラリ、検索、シャッフルの対象から一時的に除外されます。楽曲ファイルは削除されません。")
                        }
                    }

                    Section {
                        Button("ライブラリを再読み込み", systemImage: "arrow.clockwise") {
                            Task { await libraryStore.rescan() }
                        }
                        .disabled(libraryStore.isLoading)
                        Button("音楽フォルダを追加", systemImage: "folder.badge.plus") {
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
                case .genres: GenresView(genres: libraryStore.genres)
                case .composers: ComposersView(composers: libraryStore.composers)
                }
            }
            .fileImporter(
                isPresented: $isFolderImporterPresented,
                allowedContentTypes: [UTType.folder],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case let .success(urls):
                    Task { await libraryStore.addFolders(urls) }
                case let .failure(error):
                    libraryStore.reportFolderImportFailure(error)
                }
            }
            .alert("音楽ライブラリのエラー", isPresented: errorIsPresented) {
                Button("閉じる") { libraryStore.dismissError() }
            } message: {
                Text(libraryStore.errorMessage ?? "不明なエラーが発生しました。")
            }
            .alert("プリセットを保存", isPresented: $isPresetNamePresented) {
                TextField("プリセット名", text: $presetName)
                Button("キャンセル", role: .cancel) {}
                Button("保存") { libraryStore.saveGenreDisplayPreset(named: presetName) }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("現在のジャンルON/OFF設定に名前を付けます。同じ名前で保存すると上書きされます。")
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

    private func genreBinding(for genreName: String) -> Binding<Bool> {
        Binding(
            get: { libraryStore.isGenreEnabled(genreName) },
            set: { libraryStore.setGenre(genreName, isEnabled: $0) }
        )
    }

    private func presetRow(_ preset: GenreDisplayPreset) -> some View {
        HStack {
            Button {
                libraryStore.applyGenreDisplayPreset(preset)
            } label: {
                HStack {
                    Image(systemName: libraryStore.isGenreDisplayPresetActive(preset) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(libraryStore.isGenreDisplayPresetActive(preset) ? Color.accentColor : .secondary)
                    Text(preset.name)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button(role: .destructive) {
                libraryStore.deleteGenreDisplayPreset(preset)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(preset.name)を削除")
        }
    }
}

private enum LibraryDestination: Hashable {
    case songs, albums, artists, genres, composers
}
