import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private let exporter = MusicDataExportService()

    var body: some View {
        List {
            Section("ライブラリ") {
                exportLink("ライブラリをMarkdownで書き出す", systemImage: "doc.plaintext",
                    file: exporter.libraryMarkdown(tracks: libraryStore.tracks, history: historyStore.entries))
                throwingExportLink("ライブラリをJSONで書き出す", systemImage: "curlybraces") {
                    try exporter.libraryJSON(tracks: libraryStore.tracks, history: historyStore.entries)
                }
            }
            Section("プレイリスト") {
                throwingExportLink("全プレイリストを書き出す", systemImage: "square.and.arrow.up") {
                    try exporter.allPlaylistsJSON(playlistStore.playlists, tracks: libraryStore.tracks)
                }
                Button("プレイリストを読み込む", systemImage: "square.and.arrow.down") { isImporting = true }
            }
            Section("再生データ") {
                throwingExportLink("再生履歴を書き出す", systemImage: "clock.arrow.circlepath") {
                    try exporter.playbackHistoryJSON(historyStore.entries)
                }
            }
        }
        .navigationTitle("データ管理")
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .plainText]) { result in
            importFile(result)
        }
        .alert("インポート結果", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("OK") { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
        .alert("データエラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func exportLink(_ title: String, systemImage: String, file: MusicExportFile) -> some View {
        ShareLink(item: file, preview: SharePreview(file.filename)) { Label(title, systemImage: systemImage) }
    }

    @ViewBuilder private func throwingExportLink(_ title: String, systemImage: String, make: () throws -> MusicExportFile) -> some View {
        if let file = try? make() { exportLink(title, systemImage: systemImage, file: file) }
        else { Label(title, systemImage: systemImage).foregroundStyle(.secondary) }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let parsed = try MusicDataImportService().parse(data: Data(contentsOf: url), fileExtension: url.pathExtension, libraryTracks: libraryStore.tracks)
            for draft in parsed.playlists { playlistStore.importPlaylist(named: draft.name, trackIDs: draft.trackIDs) }
            resultMessage = "\(parsed.playlists.count)件のプレイリスト、\(parsed.importedTrackCount)曲を読み込みました。\n見つからない曲: \(parsed.missingTrackCount)曲"
        } catch let error as CocoaError where error.code == .userCancelled { }
        catch { errorMessage = error.localizedDescription }
    }
}
