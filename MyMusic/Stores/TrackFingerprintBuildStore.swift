import Foundation
import Observation

@MainActor
@Observable
final class TrackFingerprintBuildStore {
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var failedCount = 0
    private(set) var downloadRequiredCount = 0
    private(set) var currentTrackTitle: String?
    private(set) var isRunning = false
    private(set) var message: String?
    var allowDownloading = false {
        didSet { deferredTrackIDs.removeAll() }
    }

    var missingCount: Int { max(totalCount - completedCount, 0) }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private let identityService: TrackIdentityServicing
    private var task: Task<Void, Never>?
    private var fingerprints: [Track.ID: String] = [:]
    private var deferredTrackIDs: Set<Track.ID> = []

    init(
        identityService: TrackIdentityServicing = TrackIdentityService.shared
    ) {
        self.identityService = identityService
    }

    func refresh(tracks: [Track]) async {
        fingerprints = await identityService.fingerprints(for: tracks.map(\.id))
        totalCount = tracks.count
        completedCount = tracks.reduce(into: 0) { count, track in
            if fingerprints[track.id] != nil { count += 1 }
        }
    }

    func start(tracks: [Track], folders: [LibraryFolder]) {
        guard !isRunning else { return }
        let candidates = tracks.filter {
            fingerprints[$0.id] == nil && !deferredTrackIDs.contains($0.id)
        }
        guard !candidates.isEmpty else {
            message = missingCount == 0
                ? "すべての曲でFingerprintを作成済みです。"
                : "現在の条件で処理できる未作成曲はありません。"
            return
        }

        failedCount = 0
        downloadRequiredCount = 0
        message = nil
        isRunning = true
        task = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            for track in candidates {
                if Task.isCancelled { break }
                currentTrackTitle = track.title
                guard let folder = Self.folder(containing: track, folders: folders) else {
                    failedCount += 1
                    continue
                }
                let result = await identityService.buildFingerprint(
                    for: track,
                    in: folder.url,
                    allowDownloading: allowDownloading
                )
                if Task.isCancelled { break }
                switch result {
                case let .built(fingerprint):
                    fingerprints[track.id] = fingerprint
                    completedCount += 1
                case let .alreadyExists(fingerprint):
                    fingerprints[track.id] = fingerprint
                    completedCount += 1
                case .requiresDownload:
                    downloadRequiredCount += 1
                    deferredTrackIDs.insert(track.id)
                case .unavailable, .failed:
                    failedCount += 1
                    deferredTrackIDs.insert(track.id)
                }
            }
            currentTrackTitle = nil
            isRunning = false
            task = nil
            if Task.isCancelled {
                message = "Fingerprint作成を一時停止しました。"
            } else {
                message = "今回のFingerprint作成が完了しました。"
            }
        }
    }

    func pause() {
        guard isRunning else { return }
        task?.cancel()
    }

    private static func folder(containing track: Track, folders: [LibraryFolder]) -> LibraryFolder? {
        let trackPath = track.fileURL.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        return folders.first { folder in
            let folderPath = folder.url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
            return trackPath == folderPath || trackPath.hasPrefix(folderPath + "/")
        }
    }
}
