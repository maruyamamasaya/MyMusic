import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    private enum ImportTarget {
        case playlist
        case equalizer
        case genreDisplayPresets

        var allowedContentTypes: [UTType] {
            switch self {
            case .playlist:
                [.json, .plainText]
            case .equalizer, .genreDisplayPresets:
                [.json]
            }
        }
    }

    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrackFeatureStore.self) private var featureStore
    @State private var importTarget = ImportTarget.playlist
    @State private var isImportingFile = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var shareItem: ActivityShareItem?
    @State private var libraryFingerprints: [Track.ID: String] = [:]

    private let exporter = MusicDataExportService()

    var body: some View {
        List {
            Section("Track識別") {
                NavigationLink {
                    TrackFingerprintBuildView()
                } label: {
                    Label("Fingerprintを作成", systemImage: "waveform.badge.magnifyingglass")
                }
            }
            Section("ライブラリ") {
                exportLink("ライブラリをMarkdownで書き出す", systemImage: "doc.plaintext",
                    file: exporter.libraryMarkdown(tracks: libraryStore.tracks, history: historyStore.entries))
                throwingExportLink("ライブラリをJSONで書き出す", systemImage: "curlybraces") {
                    try exporter.libraryJSON(
                        tracks: libraryStore.unfilteredTracks,
                        history: historyStore.entries,
                        fingerprints: libraryFingerprints
                    )
                }
            }
            Section("プレイリスト") {
                throwingExportLink("全プレイリストを書き出す", systemImage: "square.and.arrow.up") {
                    try exporter.allPlaylistsJSON(playlistStore.playlists, tracks: libraryStore.tracks)
                }
                Button("プレイリストを読み込む", systemImage: "square.and.arrow.down") {
                    presentImporter(for: .playlist)
                }
            }
            Section("再生データ") {
                throwingExportLink("再生履歴を書き出す", systemImage: "clock.arrow.circlepath") {
                    try exporter.playbackHistoryJSON(historyStore.entries)
                }
                throwingExportLink("Analytics用再生イベントを書き出す", systemImage: "chart.bar.doc.horizontal") {
                    try exporter.playbackEventsJSON(
                        historyStore.entries,
                        tracks: libraryStore.unfilteredTracks
                    )
                }
                throwingExportLink("再生傾向を書き出す", systemImage: "hand.thumbsup") {
                    try exporter.playbackPreferencesJSON(historyStore.entries)
                }
            }
            Section {
                throwingExportLink("音量ノーマライズを書き出す", systemImage: "waveform.badge.magnifyingglass") {
                    try exporter.volumeNormalizationJSON(
                        featureStore.exportedFeatures,
                        tracks: libraryStore.unfilteredTracks,
                        isEnabled: settingsStore.volumeNormalizationEnabled
                    )
                }
                throwingExportLink("音楽特徴量を書き出す", systemImage: "waveform.path.ecg") {
                    try exporter.trackFeaturesJSON(
                        featureStore.exportedFeatures,
                        tracks: libraryStore.unfilteredTracks
                    )
                }
            } header: {
                Text("解析データ")
            } footer: {
                Text("音量ノーマライズは解析済みの曲だけを、音楽特徴量は保存済みの全項目を書き出します。音源ファイルは含みません。")
            }
            Section {
                throwingExportLink("イコライザーを書き出す", systemImage: "slider.horizontal.3") {
                    try exporter.equalizerJSON(
                        settings: settingsStore.equalizer,
                        customPresets: settingsStore.customEqualizerPresets
                    )
                }
                Button("イコライザーを読み込む", systemImage: "square.and.arrow.down") {
                    presentImporter(for: .equalizer)
                }
                throwingExportLink("ジャンルプリセットを書き出す", systemImage: "list.bullet.rectangle.portrait") {
                    try exporter.genreDisplayPresetsJSON(libraryStore.genreDisplayPresets)
                }
                Button("ジャンルプリセットを読み込む", systemImage: "square.and.arrow.down") {
                    presentImporter(for: .genreDisplayPresets)
                }
            } header: {
                Text("設定とプリセット")
            } footer: {
                Text("読み込み時、同名のプリセットは更新し、それ以外は追加します。現在のイコライザー設定は読み込んだ内容へ切り替わります。")
            }
        }
        .navigationTitle("データ管理")
        .activityShareSheet(item: $shareItem)
        .onAppear {
            Task { libraryFingerprints = await libraryStore.trackFingerprintsForExport() }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: importTarget.allowedContentTypes) { result in
            switch importTarget {
            case .playlist:
                importPlaylistFile(result)
            case .equalizer:
                importSettingsFile(result, expectedKind: .equalizer)
            case .genreDisplayPresets:
                importSettingsFile(result, expectedKind: .genreDisplayPresets)
            }
        }
        .alert("インポート結果", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("閉じる") { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
        .alert("データエラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("閉じる") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func presentImporter(for target: ImportTarget) {
        importTarget = target
        isImportingFile = true
    }

    private func exportLink(_ title: String, systemImage: String, file: MusicExportFile) -> some View {
        Button(title, systemImage: systemImage) {
            do {
                shareItem = try ActivityShareItem(file: file)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder private func throwingExportLink(_ title: String, systemImage: String, make: () throws -> MusicExportFile) -> some View {
        if let file = try? make() { exportLink(title, systemImage: systemImage, file: file) }
        else { Label(title, systemImage: systemImage).foregroundStyle(.secondary) }
    }

    private func importPlaylistFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let parsed = try MusicDataImportService().parse(data: Data(contentsOf: url), fileExtension: url.pathExtension, libraryTracks: libraryStore.tracks)
            let tracksByID = Dictionary(uniqueKeysWithValues: libraryStore.tracks.map { ($0.id, $0) })
            for draft in parsed.playlists {
                playlistStore.importPlaylist(
                    named: draft.name,
                    tracks: draft.trackIDs.compactMap { tracksByID[$0] },
                    kind: draft.kind,
                    tags: draft.tags
                )
            }
            resultMessage = "\(parsed.playlists.count)件のプレイリスト、\(parsed.importedTrackCount)曲を読み込みました。\n見つからない曲: \(parsed.missingTrackCount)曲\n種別が異なる曲: \(parsed.incompatibleTrackCount)曲"
        } catch let error as CocoaError where error.code == .userCancelled { }
        catch { errorMessage = error.localizedDescription }
    }

    private func importSettingsFile(
        _ result: Result<URL, Error>,
        expectedKind: MusicSettingsDocumentKind
    ) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let payload = try MusicSettingsImportService().parse(data: Data(contentsOf: url))

            switch (expectedKind, payload) {
            case let (.equalizer, .equalizer(settings, customPresets)):
                let counts = settingsStore.importEqualizer(settings, customPresets: customPresets)
                resultMessage = "イコライザー設定を読み込みました。\nプリセット追加: \(counts.added)件\n更新: \(counts.updated)件"

            case let (.genreDisplayPresets, .genreDisplayPresets(presets)):
                let counts = libraryStore.importGenreDisplayPresets(presets)
                resultMessage = "ジャンルプリセットを読み込みました。\n追加: \(counts.added)件\n更新: \(counts.updated)件"

            default:
                throw MusicSettingsImportError.unsupportedDocument
            }
        } catch let error as CocoaError where error.code == .userCancelled { }
        catch { errorMessage = error.localizedDescription }
    }
}
