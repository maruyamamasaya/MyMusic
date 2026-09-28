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
    private(set) var sourceEventCount = 0
    private(set) var availableDateRange: ClosedRange<Date>?

    @ObservationIgnored private let service = PlaybackEventImportService()
    @ObservationIgnored private var sourceDocument: PlaybackEventImportDocument?
    @ObservationIgnored private var pendingDocument: PlaybackEventImportDocument?
    @ObservationIgnored private var history: [Track.ID: PlaybackHistory] = [:]
    @ObservationIgnored private var libraryTrackIDs = Set<Track.ID>()

    var isBusy: Bool { state == .validating || state == .applying }

    func prepare(
        data: Data,
        history: [Track.ID: PlaybackHistory],
        libraryTrackIDs: Set<Track.ID>
    ) {
        guard state != .validating, state != .applying, state != .preview else { return }
        state = .validating
        sourceDocument = nil
        pendingDocument = nil
        self.history.removeAll()
        self.libraryTrackIDs.removeAll()
        sourceEventCount = 0
        availableDateRange = nil
        preview = nil
        result = nil
        errorMessage = nil
        do {
            let document = try service.parse(data: data)
            sourceDocument = document
            sourceEventCount = document.events.count
            availableDateRange = dateRange(for: document)
            self.history = history
            self.libraryTrackIDs = libraryTrackIDs
            if let availableDateRange {
                updatePeriod(
                    from: availableDateRange.lowerBound,
                    through: availableDateRange.upperBound
                )
            } else {
                pendingDocument = document
                preview = service.preview(
                    document,
                    history: history,
                    libraryTrackIDs: libraryTrackIDs
                )
            }
            state = .preview
        } catch {
            sourceDocument = nil
            pendingDocument = nil
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    func updatePeriod(from startDate: Date, through endDate: Date) {
        guard let sourceDocument else { return }
        let filtered = service.filtered(
            sourceDocument,
            from: startDate,
            through: endDate
        )
        pendingDocument = filtered
        preview = service.preview(
            filtered,
            history: history,
            libraryTrackIDs: libraryTrackIDs
        )
    }

    func apply(to historyStore: PlaybackHistoryStore) async {
        guard state == .preview, let document = pendingDocument else { return }
        state = .applying
        do {
            result = try await historyStore.importPlaybackEvents(
                document,
                libraryTrackIDs: libraryTrackIDs
            )
            sourceDocument = nil
            pendingDocument = nil
            history.removeAll()
            libraryTrackIDs.removeAll()
            sourceEventCount = 0
            preview = nil
            availableDateRange = nil
            state = .completed
        } catch {
            errorMessage = "再生イベントを保存できませんでした: \(error.localizedDescription)"
            state = .failed
        }
    }

    func cancel() {
        guard state == .preview else { return }
        sourceDocument = nil
        pendingDocument = nil
        history.removeAll()
        libraryTrackIDs.removeAll()
        sourceEventCount = 0
        availableDateRange = nil
        preview = nil
        state = .idle
    }

    func reset() {
        guard !isBusy else { return }
        sourceDocument = nil
        pendingDocument = nil
        history.removeAll()
        libraryTrackIDs.removeAll()
        sourceEventCount = 0
        availableDateRange = nil
        preview = nil
        result = nil
        errorMessage = nil
        state = .idle
    }

    func reportFileReadError(_ error: Error) {
        guard !isBusy else { return }
        sourceDocument = nil
        pendingDocument = nil
        history.removeAll()
        libraryTrackIDs.removeAll()
        sourceEventCount = 0
        availableDateRange = nil
        preview = nil
        result = nil
        errorMessage = "ファイルを読み込めませんでした: \(error.localizedDescription)"
        state = .failed
    }

    private func dateRange(for document: PlaybackEventImportDocument) -> ClosedRange<Date>? {
        guard let first = document.events.map(\.event.startedAt).min(),
              let last = document.events.map(\.event.startedAt).max() else { return nil }
        let calendar = Calendar.current
        return calendar.startOfDay(for: first) ... calendar.startOfDay(for: last)
    }
}
