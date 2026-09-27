import Foundation
import Observation

@MainActor
@Observable
final class PlaybackEventImportStore {
    enum State: Equatable {
        case idle
        case validating
        case preview
        case applying
        case completed
        case failed
    }

    private(set) var state: State = .idle
    private(set) var preview: PlaybackEventImportPreview?
    private(set) var result: PlaybackEventImportResult?
    private(set) var errorMessage: String?

    @ObservationIgnored private let service = PlaybackEventImportService()
    @ObservationIgnored private var pendingDocument: PlaybackEventImportDocument?
    @ObservationIgnored private var libraryTrackIDs = Set<Track.ID>()

    var isBusy: Bool { state == .validating || state == .applying }

    func prepare(
        data: Data,
        history: [Track.ID: PlaybackHistory],
        libraryTrackIDs: Set<Track.ID>
    ) {
        guard state != .validating, state != .applying, state != .preview else { return }
        state = .validating
        preview = nil
        result = nil
        errorMessage = nil
        do {
            let document = try service.parse(data: data)
            let preview = service.preview(
                document,
                history: history,
                libraryTrackIDs: libraryTrackIDs
            )
            pendingDocument = document
            self.libraryTrackIDs = libraryTrackIDs
            self.preview = preview
            state = .preview
        } catch {
            pendingDocument = nil
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    func apply(to historyStore: PlaybackHistoryStore) async {
        guard state == .preview, let document = pendingDocument else { return }
        state = .applying
        do {
            result = try await historyStore.importPlaybackEvents(
                document,
                libraryTrackIDs: libraryTrackIDs
            )
            pendingDocument = nil
            preview = nil
            state = .completed
        } catch {
            errorMessage = "再生イベントを保存できませんでした: \(error.localizedDescription)"
            state = .failed
        }
    }

    func cancel() {
        guard state == .preview else { return }
        pendingDocument = nil
        preview = nil
        state = .idle
    }

    func reset() {
        guard !isBusy else { return }
        pendingDocument = nil
        libraryTrackIDs.removeAll()
        preview = nil
        result = nil
        errorMessage = nil
        state = .idle
    }

    func reportFileReadError(_ error: Error) {
        guard !isBusy else { return }
        pendingDocument = nil
        preview = nil
        result = nil
        errorMessage = "ファイルを読み込めませんでした: \(error.localizedDescription)"
        state = .failed
    }
}
