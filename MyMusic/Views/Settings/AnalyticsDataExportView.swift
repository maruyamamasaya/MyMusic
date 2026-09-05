import SwiftUI

struct AnalyticsDataExportView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TrackFeatureStore.self) private var featureStore
    @State private var shareItem: ActivityShareItem?
    @State private var errorMessage: String?
    @State private var libraryFingerprints: [Track.ID: String] = [:]
    @State private var isExportingArchive = false

    private let exporter = MusicDataExportService()
    private let archiveExporter = AnalyticsArchiveExportService()

    var body: some View {
        List {
            Section {
                Button {
                    exportArchive()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isExportingArchive ? "書き出し中…" : "すべてまとめて書き出す")
                            Text("8種類のJSONをZIPにまとめます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        if isExportingArchive {
                            ProgressView()
                        } else {
                            Image(systemName: "archivebox")
                        }
                    }
                }
                .disabled(isExportingArchive)
            }
            Section {
                exportButton("ライブラリ", filename: "MyMusic-Library.json", systemImage: "books.vertical") {
                    try exporter.libraryJSON(
                        tracks: libraryStore.unfilteredTracks,
                        history: historyStore.entries,
                        preferences: preferenceStore.entries,
                        fingerprints: libraryFingerprints
                    )
                }
                exportButton("再生イベント", filename: "MyMusic-Playback-Events.json", systemImage: "chart.bar.doc.horizontal") {
                    try exporter.playbackEventsJSON(
                        historyStore.entries,
                        tracks: libraryStore.unfilteredTracks
                    )
                }
                exportButton("再生傾向", filename: "MyMusic-Playback-Preferences.json", systemImage: "hand.thumbsup") {
                    try exporter.playbackPreferencesJSON(preferenceStore.entries)
                }
                exportButton("音楽特徴量", filename: "MyMusic-Track-Features.json", systemImage: "waveform.path.ecg") {
                    try exporter.trackFeaturesJSON(
                        featureStore.exportedFeatures,
                        tracks: libraryStore.unfilteredTracks
                    )
                }
                exportButton("音量ノーマライズ", filename: "MyMusic-Volume-Normalization.json", systemImage: "waveform.badge.magnifyingglass") {
                    try exporter.volumeNormalizationJSON(
                        featureStore.exportedFeatures,
                        tracks: libraryStore.unfilteredTracks,
                        isEnabled: settingsStore.volumeNormalizationEnabled
                    )
                }
                exportButton("プレイリスト", filename: "MyMusic-Playlists.json", systemImage: "music.note.list") {
                    try exporter.allPlaylistsJSON(
                        playlistStore.playlists,
                        tracks: libraryStore.tracks
                    )
                }
                exportButton("イコライザー", filename: "MyMusic-Equalizer.json", systemImage: "slider.horizontal.3") {
                    try exporter.equalizerJSON(
                        settings: settingsStore.equalizer,
                        customPresets: settingsStore.customEqualizerPresets
                    )
                }
                exportButton("ジャンルプリセット", filename: "MyMusic-Genre-Display-Presets.json", systemImage: "list.bullet.rectangle.portrait") {
                    try exporter.genreDisplayPresetsJSON(libraryStore.genreDisplayPresets)
                }
            } footer: {
                Text("PC版Analyticsへ取り込むためのJSONを書き出します。オンライン同期は行いません。")
            }
        }
        .navigationTitle("Analyticsと同期")
        .activityShareSheet(item: $shareItem)
        .onAppear {
            Task { libraryFingerprints = await libraryStore.trackFingerprintsForExport() }
        }
        .alert("書き出しエラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("閉じる") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func exportArchive() {
        isExportingArchive = true
        Task { @MainActor in
            defer { isExportingArchive = false }
            do {
                let exportedAt = Date()
                let files = try analyticsFiles(exportedAt: exportedAt)
                let archive = try await archiveExporter.archive(
                    files: files,
                    exportedAt: exportedAt
                )
                shareItem = try ActivityShareItem(file: archive)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func analyticsFiles(exportedAt: Date) throws -> [MusicExportFile] {
        [
            try exporter.libraryJSON(
                tracks: libraryStore.unfilteredTracks,
                history: historyStore.entries,
                preferences: preferenceStore.entries,
                fingerprints: libraryFingerprints
            ),
            try exporter.playbackEventsJSON(
                historyStore.entries,
                tracks: libraryStore.unfilteredTracks,
                exportedAt: exportedAt
            ),
            try exporter.playbackPreferencesJSON(
                preferenceStore.entries,
                exportedAt: exportedAt
            ),
            try exporter.trackFeaturesJSON(
                featureStore.exportedFeatures,
                tracks: libraryStore.unfilteredTracks,
                exportedAt: exportedAt
            ),
            try exporter.volumeNormalizationJSON(
                featureStore.exportedFeatures,
                tracks: libraryStore.unfilteredTracks,
                isEnabled: settingsStore.volumeNormalizationEnabled,
                exportedAt: exportedAt
            ),
            try exporter.allPlaylistsJSON(
                playlistStore.playlists,
                tracks: libraryStore.tracks
            ),
            try exporter.equalizerJSON(
                settings: settingsStore.equalizer,
                customPresets: settingsStore.customEqualizerPresets
            ),
            try exporter.genreDisplayPresetsJSON(libraryStore.genreDisplayPresets)
        ]
    }

    private func exportButton(
        _ title: String,
        filename: String,
        systemImage: String,
        makeFile: @escaping () throws -> MusicExportFile
    ) -> some View {
        Button {
            do {
                shareItem = try ActivityShareItem(file: makeFile())
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
