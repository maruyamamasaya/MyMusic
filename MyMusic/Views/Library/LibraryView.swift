import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var isFolderImporterPresented = false

    private let collapsedFolderLimit = 4

    var body: some View {
        NavigationStack {
            List {
                Section("音楽ライブラリ") {
                    if libraryStore.hasLibraryFolder {
                        ForEach(visibleLibraryFolders) { folder in
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

                        if libraryStore.libraryFolders.count > collapsedFolderLimit {
                            NavigationLink {
                                LibraryFoldersView()
                            } label: {
                                Label("もっと見る", systemImage: "ellipsis")
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
                            if let total = libraryStore.scanTotalCount {
                                ProgressView(
                                    value: Double(libraryStore.scanCompletedCount),
                                    total: Double(max(total, 1))
                                )
                            } else {
                                ProgressView()
                            }
                            Text(libraryStore.scanFolderName.map { "\($0) を同期中…" } ?? "音楽ライブラリを同期中…")
                            if let total = libraryStore.scanTotalCount,
                               let remaining = libraryStore.scanRemainingCount {
                                Text("同期対象 \(total) 曲・完了 \(libraryStore.scanCompletedCount) 曲・残り \(remaining) 曲")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("ファイル一覧を確認しています")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                            NavigationLink {
                                GenreDisplaySettingsView()
                            } label: {
                                HStack {
                                    Label("ジャンルごとの表示", systemImage: "line.3.horizontal.decrease.circle")
                                    Spacer()
                                    Text("\(enabledGenreCount)/\(libraryStore.availableGenreOptions.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            Text("OFFにしたジャンルはライブラリ、検索、シャッフルの対象から一時的に除外されます。楽曲ファイルは削除されません。")
                        }
                    }

                    Section {
                        Button("クイック同期", systemImage: "arrow.clockwise") {
                            Task { await libraryStore.rescan(depth: .quick) }
                        }
                        .disabled(libraryStore.isLoading)
                        Button("メタデータと画像を再取得", systemImage: "arrow.triangle.2.circlepath") {
                            Task { await libraryStore.rescan(depth: .complete) }
                        }
                        .disabled(libraryStore.isLoading)
                        Button("音楽フォルダを追加", systemImage: "folder.badge.plus") {
                            isFolderImporterPresented = true
                        }
                        .disabled(libraryStore.isLoading)
                    } footer: {
                        Text("クイック同期は変更されたファイルだけを確認します。再取得は全曲のタグとアートワークを読み直しますが、曲のUUIDと再生統計の紐付けは維持します。中断後10分以内は取得済みの曲から再開します。")
                    }
                } else {
                    Button("音楽フォルダを選択", systemImage: "folder.badge.plus") {
                        isFolderImporterPresented = true
                    }
                }
            }
            .themeScreen()
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

    private var enabledGenreCount: Int {
        libraryStore.availableGenreOptions.count { libraryStore.isGenreEnabled($0.id) }
    }

    private var visibleLibraryFolders: ArraySlice<LibraryFolder> {
        libraryStore.libraryFolders.prefix(collapsedFolderLimit)
    }
}

private enum LibraryDestination: Hashable {
    case songs, albums, artists, genres, composers
}
