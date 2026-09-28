import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    ExternalBackupView()
                } label: {
                    DataManagementLinkLabel(
                        title: "App外バックアップ",
                        description: "重要データをFilesまたはiCloud Driveへ保存・復元",
                        systemImage: "externaldrive.badge.icloud"
                    )
                }

                NavigationLink {
                    AnalyticsDataExportView()
                } label: {
                    DataManagementLinkLabel(
                        title: "Analyticsと同期",
                        description: "ローカル分析で使うデータをまとめて書き出す",
                        systemImage: "arrow.up.doc"
                    )
                }
            } header: {
                Text("保護と同期")
            }

            Section {
                detailLink(
                    .library,
                    description: "ライブラリ一覧とTrack識別情報"
                )
                detailLink(
                    .playlists,
                    description: "通常・作業用プレイリスト"
                )
                detailLink(
                    .playback,
                    description: "再生履歴・イベント・再生傾向"
                )
                detailLink(
                    .analysis,
                    description: "音量ノーマライズと音楽特徴量"
                )
                detailLink(
                    .settings,
                    description: "イコライザーとジャンルプリセット"
                )
            } header: {
                Text("読み込み・書き出し")
            } footer: {
                Text("扱うデータの種類を選ぶと、利用できる読み込み・書き出し操作を確認できます。")
            }
        }
        .themeScreen()
        .navigationTitle("データ管理")
    }

    private func detailLink(
        _ category: DataManagementCategory,
        description: String
    ) -> some View {
        NavigationLink {
            DataManagementDetailView(category: category)
        } label: {
            DataManagementLinkLabel(
                title: category.title,
                description: description,
                systemImage: category.systemImage
            )
        }
    }
}

private struct DataManagementLinkLabel: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

private enum DataManagementCategory {
    case library
    case playlists
    case playback
    case analysis
    case settings

    var title: String {
        switch self {
        case .library: "ライブラリとTrack識別"
        case .playlists: "プレイリスト"
        case .playback: "再生データ"
        case .analysis: "解析データ"
        case .settings: "設定とプリセット"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "music.note.house"
        case .playlists: "music.note.list"
        case .playback: "clock.arrow.circlepath"
        case .analysis: "waveform.path.ecg"
        case .settings: "slider.horizontal.3"
        }
    }
}

private struct DataManagementDetailView: View {
    private enum ImportTarget {
        case playlist
        case playbackPreferences
        case equalizer
        case genreDisplayPresets

        var allowedContentTypes: [UTType] {
            switch self {
            case .playlist:
                [.json, .plainText]
            case .playbackPreferences, .equalizer, .genreDisplayPresets:
                [.json]
            }
        }
    }

    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
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

    let category: DataManagementCategory

    var body: some View {
        List {
            switch category {
            case .library:
                librarySections
            case .playlists:
                playlistSections
            case .playback:
                playbackSections
            case .analysis:
                analysisSections
            case .settings:
                settingsSections
            }
        }
        .themeScreen()
        .navigationTitle(category.title)
        .activityShareSheet(item: $shareItem)
        .task {
            guard category == .library else { return }
            libraryFingerprints = await libraryStore.trackFingerprintsForExport()
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: importTarget.allowedContentTypes) { result in
            switch importTarget {
            case .playlist:
                importPlaylistFile(result)
            case .playbackPreferences:
                importPreferenceFile(result)
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

    @ViewBuilder private var librarySections: some View {
        Section("Track識別") {
            NavigationLink {
                TrackFingerprintBuildView()
            } label: {
                Label("Fingerprintを作成", systemImage: "waveform.badge.magnifyingglass")
            }
        }
        Section("書き出し") {
            exportLink("ライブラリをMarkdownで書き出す", systemImage: "doc.plaintext",
                file: exporter.libraryMarkdown(
                    tracks: libraryStore.tracks, history: historyStore.entries,
                    preferences: preferenceStore.entries
                ))
            throwingExportLink("ライブラリをJSONで書き出す", systemImage: "curlybraces") {
                try exporter.libraryJSON(
                    tracks: libraryStore.unfilteredTracks,
                    history: historyStore.entries,
                    preferences: preferenceStore.entries,
                    fingerprints: libraryFingerprints
                )
            }
        }
    }

    @ViewBuilder private var playlistSections: some View {
        Section {
            throwingExportLink("全プレイリストを書き出す", systemImage: "square.and.arrow.up") {
                try exporter.allPlaylistsJSON(
                    playlistStore.playlists,
                    tracks: libraryStore.unfilteredTracks
                )
            }
            throwingExportLink("通常プレイリストを書き出す", systemImage: "music.note.list") {
                try exporter.playlistsJSON(
                    playlistStore.playlists,
                    kind: .regular,
                    tracks: libraryStore.unfilteredTracks
                )
            }
            throwingExportLink("作業用プレイリストを書き出す", systemImage: "timer") {
                try exporter.playlistsJSON(
                    playlistStore.playlists,
                    kind: .work,
                    tracks: libraryStore.unfilteredTracks
                )
            }
            Button("プレイリストを読み込む", systemImage: "square.and.arrow.down") {
                presentImporter(for: .playlist)
            }
        } header: {
            Text("プレイリスト")
        } footer: {
            Text("全プレイリストは完全な同期用です。通常用と作業用は用途別に分けて共有できます。")
        }
    }

    @ViewBuilder private var playbackSections: some View {
        Section("読み込み") {
            NavigationLink {
                PlaybackEventImportView()
            } label: {
                Label("再生イベントJSONを読み込む", systemImage: "square.and.arrow.down")
            }
            Button("再生傾向を読み込む", systemImage: "square.and.arrow.down") {
                presentImporter(for: .playbackPreferences)
            }
        }
        Section("書き出し") {
            throwingExportLink("再生履歴を書き出す", systemImage: "clock.arrow.circlepath") {
                try exporter.playbackHistoryJSON(
                    historyStore.entries, preferences: preferenceStore.entries
                )
            }
            throwingExportLink("Analytics用再生イベントを書き出す", systemImage: "chart.bar.doc.horizontal") {
                try exporter.playbackEventsJSON(
                    historyStore.entries,
                    tracks: libraryStore.unfilteredTracks
                )
            }
            throwingExportLink("再生傾向を書き出す", systemImage: "hand.thumbsup") {
                try exporter.playbackPreferencesJSON(preferenceStore.entries)
            }
        }
    }

    @ViewBuilder private var analysisSections: some View {
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
    }

    @ViewBuilder private var settingsSections: some View {
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

    private func importPreferenceFile(_ result: Result<URL, Error>) {
        Task { @MainActor in
            do {
                let url = try result.get()
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let imported = try TrackPreferenceImportService().parse(data: Data(contentsOf: url))
                let report = try await preferenceStore.importPreferences(
                    imported,
                    libraryTrackIDs: Set(libraryStore.unfilteredTracks.map(\.id))
                )
                resultMessage = "合計: \(report.total)件\n更新: \(report.updated)件\n変更なし: \(report.unchanged)件\nLibraryに存在しないTrack: \(report.missingTrack)件\n不正: \(report.invalid)件"
            } catch let error as CocoaError where error.code == .userCancelled { }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
