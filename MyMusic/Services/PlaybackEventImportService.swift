import Foundation

enum PlaybackEventImportError: LocalizedError, Equatable {
    case invalidStructure(String)
    case unsupportedSchemaVersion(Int)
    case unsupportedEventSchemaVersion(index: Int, version: Int)
    case invalidEventID(index: Int)
    case duplicateEventID(String)
    case invalidTrackID(index: Int, value: String)
    case invalidDuration(index: Int)
    case inconsistentCompletion(index: Int)
    case unsupportedSelectionType(index: Int, value: String)
    case unsupportedPlaySource(index: Int, value: String)
    case unsupportedPlatform(index: Int, value: String)

    var errorDescription: String? {
        switch self {
        case let .invalidStructure(detail):
            "再生イベントJSONの構造が不正です: \(detail)"
        case let .unsupportedSchemaVersion(version):
            "再生イベントJSONのschemaVersion \(version)には対応していません。対応バージョンは1です。"
        case let .unsupportedEventSchemaVersion(index, version):
            "events[\(index)]のschemaVersion \(version)には対応していません。"
        case let .invalidEventID(index):
            "events[\(index)]のeventIdが空です。"
        case let .duplicateEventID(id):
            "同じeventIdが文書内で重複しています: \(id)"
        case let .invalidTrackID(index, value):
            "events[\(index)]のtrackIdがUUIDではありません: \(value)"
        case let .invalidDuration(index):
            "events[\(index)]の再生時間が不正です。playDurationは0以上、trackDurationは0より大きい有限値が必要です。"
        case let .inconsistentCompletion(index):
            "events[\(index)]のcompletedが再生時間から計算した値と一致しません。"
        case let .unsupportedSelectionType(index, value):
            "events[\(index)]のselectionTypeには対応していません: \(value)"
        case let .unsupportedPlaySource(index, value):
            "events[\(index)]のplaySourceには対応していません: \(value)"
        case let .unsupportedPlatform(index, value):
            "events[\(index)]のplatformには対応していません: \(value)"
        }
    }
}

struct PlaybackEventImportCandidate: Equatable, Sendable {
    let event: PlaybackEvent
    let trackDuration: TimeInterval
    let trackTitle: String
    let artist: String
    let album: String?
}

struct PlaybackEventImportDocument: Equatable, Sendable {
    let exportedAt: Date
    let events: [PlaybackEventImportCandidate]
}

enum PlaybackEventImportDisposition: String, Equatable, Sendable {
    case insert = "追加予定"
    case duplicate = "重複"
    case unresolved = "未解決"
}

struct PlaybackEventImportPreviewDetail: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let playedAt: Date
    let platform: PlaybackPlatform
    let disposition: PlaybackEventImportDisposition
    let reason: String?
}

struct PlaybackEventImportPreview: Equatable, Sendable {
    let total: Int
    let pendingInsert: Int
    let duplicate: Int
    let unresolved: Int
    let invalid: Int
    let details: [PlaybackEventImportPreviewDetail]
}

struct PlaybackEventImportResult: Equatable, Sendable {
    let total: Int
    let inserted: Int
    let duplicate: Int
    let unresolved: Int
    let invalid: Int
}

struct PlaybackEventImportService {
    private struct Document: Decodable {
        let schemaVersion: Int
        let exportedAt: Date
        let events: [Item]
    }

    private struct Item: Decodable {
        let eventId: String
        let trackId: String
        let trackTitle: String
        let artist: String
        let album: String?
        let playedAt: Date
        let playDuration: TimeInterval
        let trackDuration: TimeInterval
        let completed: Bool
        let skipped: Bool
        let playSource: String
        let selectionType: String
        let platform: String
        let schemaVersion: Int
    }

    /// The v1 contract rejects unknown fields and inconsistent completion flags.
    /// This avoids silently normalizing a document that may have different semantics.
    func parse(data: Data) throws -> PlaybackEventImportDocument {
        try validateKeys(data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw PlaybackEventImportError.invalidStructure(error.localizedDescription)
        }
        guard document.schemaVersion == 1 else {
            throw PlaybackEventImportError.unsupportedSchemaVersion(document.schemaVersion)
        }

        var eventIDs = Set<String>()
        let events = try document.events.enumerated().map { index, item in
            guard item.schemaVersion == 1 else {
                throw PlaybackEventImportError.unsupportedEventSchemaVersion(
                    index: index, version: item.schemaVersion
                )
            }
            let eventID = item.eventId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !eventID.isEmpty else { throw PlaybackEventImportError.invalidEventID(index: index) }
            guard eventIDs.insert(eventID).inserted else {
                throw PlaybackEventImportError.duplicateEventID(eventID)
            }
            guard let trackID = UUID(uuidString: item.trackId) else {
                throw PlaybackEventImportError.invalidTrackID(index: index, value: item.trackId)
            }
            guard item.playDuration.isFinite, item.playDuration >= 0,
                  item.trackDuration.isFinite, item.trackDuration > 0 else {
                throw PlaybackEventImportError.invalidDuration(index: index)
            }
            guard !(item.completed && item.skipped) else {
                throw PlaybackEventImportError.inconsistentCompletion(index: index)
            }
            let calculatedCompleted = item.playDuration >= max(3, item.trackDuration * 0.94)
            guard item.completed == calculatedCompleted else {
                throw PlaybackEventImportError.inconsistentCompletion(index: index)
            }
            guard let startKind = PlaybackStartKind(rawValue: item.selectionType) else {
                throw PlaybackEventImportError.unsupportedSelectionType(index: index, value: item.selectionType)
            }
            guard let startSource = PlaybackStartSource(rawValue: item.playSource) else {
                throw PlaybackEventImportError.unsupportedPlaySource(index: index, value: item.playSource)
            }
            guard let platform = PlaybackPlatform(rawValue: item.platform) else {
                throw PlaybackEventImportError.unsupportedPlatform(index: index, value: item.platform)
            }
            let endKind: PlaybackEndKind = item.completed ? .natural : (item.skipped ? .userSkipped : .other)
            let event = PlaybackEvent(
                id: eventID,
                trackID: trackID,
                startedAt: item.playedAt,
                endedAt: item.playedAt.addingTimeInterval(item.playDuration),
                listenedSeconds: item.playDuration,
                completionRatio: min(max(item.playDuration / item.trackDuration, 0), 1),
                wasSkipped: item.skipped,
                wasFullPlayback: item.completed,
                startKind: startKind,
                startSource: startSource,
                endKind: endKind,
                platform: platform
            )
            return PlaybackEventImportCandidate(
                event: event,
                trackDuration: item.trackDuration,
                trackTitle: item.trackTitle,
                artist: item.artist,
                album: item.album
            )
        }
        return PlaybackEventImportDocument(exportedAt: document.exportedAt, events: events)
    }

    func preview(
        _ document: PlaybackEventImportDocument,
        history: [Track.ID: PlaybackHistory],
        libraryTrackIDs: Set<Track.ID>
    ) -> PlaybackEventImportPreview {
        let existingIDs = Set(history.values.flatMap(\.playbackEvents).map(\.id))
        var pendingInsert = 0
        var duplicate = 0
        var unresolved = 0
        var details: [PlaybackEventImportPreviewDetail] = []
        for candidate in document.events {
            let disposition: PlaybackEventImportDisposition
            let reason: String?
            if existingIDs.contains(candidate.event.id) {
                duplicate += 1
                disposition = .duplicate
                reason = "同じeventIdが保存済みです"
            } else if !libraryTrackIDs.contains(candidate.event.trackID) {
                unresolved += 1
                disposition = .unresolved
                reason = "現在のLibraryにtrackIdがありません"
            } else {
                pendingInsert += 1
                disposition = .insert
                reason = nil
            }
            if details.count < 100 {
                details.append(PlaybackEventImportPreviewDetail(
                    id: candidate.event.id,
                    title: candidate.trackTitle,
                    artist: candidate.artist,
                    playedAt: candidate.event.startedAt,
                    platform: candidate.event.platform,
                    disposition: disposition,
                    reason: reason
                ))
            }
        }
        return PlaybackEventImportPreview(
            total: document.events.count,
            pendingInsert: pendingInsert,
            duplicate: duplicate,
            unresolved: unresolved,
            invalid: 0,
            details: details
        )
    }

    private func validateKeys(data: Data) throws {
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: data) }
        catch { throw PlaybackEventImportError.invalidStructure(error.localizedDescription) }
        guard let root = object as? [String: Any] else {
            throw PlaybackEventImportError.invalidStructure("ルートはobjectである必要があります。")
        }
        let rootKeys: Set<String> = ["schemaVersion", "exportedAt", "events"]
        guard Set(root.keys) == rootKeys, let events = root["events"] as? [Any] else {
            throw PlaybackEventImportError.invalidStructure("rootの必須field不足または未知fieldを確認してください。")
        }
        let requiredItemKeys: Set<String> = [
            "eventId", "trackId", "trackTitle", "artist", "playedAt", "playDuration",
            "trackDuration", "completed", "skipped", "playSource", "selectionType",
            "platform", "schemaVersion"
        ]
        let allowedItemKeys = requiredItemKeys.union(["album"])
        for (index, value) in events.enumerated() {
            guard let item = value as? [String: Any],
                  requiredItemKeys.isSubset(of: Set(item.keys)),
                  Set(item.keys).isSubset(of: allowedItemKeys) else {
                throw PlaybackEventImportError.invalidStructure(
                    "events[\(index)]に必須field不足または未知fieldがあります。"
                )
            }
        }
    }
}

nonisolated enum PlaybackEventImportAggregation {
    static func merging(
        _ candidate: PlaybackEventImportCandidate,
        into existing: PlaybackHistory?
    ) -> PlaybackHistory {
        let event = candidate.event
        var entry = existing ?? PlaybackHistory(
            trackID: event.trackID,
            isFavorite: false,
            playCount: 0,
            lastPlayedAt: nil
        )
        entry.firstPlayedAt = minDate(entry.firstPlayedAt, event.startedAt)
        entry.lastPlayedAt = maxDate(entry.lastPlayedAt, event.startedAt)
        if countsAsPlay(candidate) { entry.playCount += 1 }
        switch event.startKind {
        case .manual, .userAdvanced: entry.manualPlayCount += 1
        case .automatic: entry.automaticPlayCount += 1
        }
        entry.playbackSourceCounts[event.startSource.rawValue, default: 0] += 1
        entry.totalPlaybackDuration += event.listenedSeconds
        if event.wasSkipped { entry.skipCount += 1 }
        if event.wasFullPlayback { entry.fullPlaybackCount += 1 }
        entry.playbackEvents.append(event)

        let key = dayKey(for: event.startedAt)
        var summary = entry.dailySummaries[key] ?? PlaybackDailySummary()
        summary.playCount += 1
        switch event.startKind {
        case .manual, .userAdvanced: summary.manualPlayCount += 1
        case .automatic: summary.automaticPlayCount += 1
        }
        if event.wasFullPlayback { summary.fullPlaybackCount += 1 }
        if event.wasSkipped { summary.skipCount += 1 }
        if event.isEarlySkip { summary.earlySkipCount += 1 }
        summary.sourceCounts[event.startSource.rawValue, default: 0] += 1
        entry.dailySummaries[key] = summary
        return entry
    }

    static func countsAsPlay(_ candidate: PlaybackEventImportCandidate) -> Bool {
        candidate.event.listenedSeconds >= min(30, candidate.trackDuration * 0.5)
    }

    private static func minDate(_ lhs: Date?, _ rhs: Date) -> Date { lhs.map { min($0, rhs) } ?? rhs }
    private static func maxDate(_ lhs: Date?, _ rhs: Date) -> Date { lhs.map { max($0, rhs) } ?? rhs }

    private static func dayKey(for date: Date, calendar: Calendar = .playbackHistory) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
