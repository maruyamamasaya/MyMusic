import Foundation
import Observation

@MainActor
@Observable
final class TrackFingerprintBuildStore {
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var processedToday = 0
    private(set) var failedCount = 0
    private(set) var downloadRequiredCount = 0
    private(set) var currentTrackTitle: String?
    private(set) var isRunning = false
    private(set) var message: String?
    var allowDownloading = false {
        didSet { deferredTrackIDs.removeAll() }
    }

    var missingCount: Int { max(totalCount - completedCount, 0) }
    var dailyLimit: Int { maximumPerDay }
    var dailyRemaining: Int { max(maximumPerDay - processedToday, 0) }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private let identityService: TrackIdentityServicing
    private let defaults: UserDefaults
    private let maximumPerDay: Int
    private var task: Task<Void, Never>?
    private var fingerprints: [Track.ID: String] = [:]
    private var deferredTrackIDs: Set<Track.ID> = []
    private static let progressDateKey = "trackFingerprintBuild.progressDate"
    private static let progressCountKey = "trackFingerprintBuild.progressCount"

    init(
        identityService: TrackIdentityServicing = TrackIdentityService.shared,
        defaults: UserDefaults = .standard,
        maximumPerDay: Int = 100
    ) {
        self.identityService = identityService
        self.defaults = defaults
        self.maximumPerDay = max(maximumPerDay, 1)
        loadDailyProgress()
    }

    func refresh(tracks: [Track]) async {
        loadDailyProgress()
        fingerprints = await identityService.fingerprints(for: tracks.map(\.id))
        totalCount = tracks.count
        completedCount = tracks.reduce(into: 0) { count, track in
            if fingerprints[track.id] != nil { count += 1 }
        }
    }

    func start(tracks: [Track], folders: [LibraryFolder]) {
        guard !isRunning else { return }
        guard dailyRemaining > 0 else {
            message = "本日の上限\(maximumPerDay)曲に達しました。続きは明日作成できます。"
            return
        }
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
        let limit = dailyRemaining
        task = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            var attempted = 0
            for track in candidates {
                if attempted >= limit || Task.isCancelled { break }
                attempted += 1
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
                    processedToday += 1
                    saveDailyProgress()
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
            } else if processedToday >= maximumPerDay {
                message = "本日の上限\(maximumPerDay)曲まで作成しました。"
            } else {
                message = "今回のFingerprint作成が完了しました。"
            }
        }
    }

    func pause() {
        guard isRunning else { return }
        task?.cancel()
    }

    private func loadDailyProgress(now: Date = Date()) {
        let today = Self.dayKey(now)
        if defaults.string(forKey: Self.progressDateKey) == today {
            processedToday = defaults.integer(forKey: Self.progressCountKey)
        } else {
            processedToday = 0
            defaults.set(today, forKey: Self.progressDateKey)
            defaults.set(0, forKey: Self.progressCountKey)
        }
    }

    private func saveDailyProgress() {
        defaults.set(Self.dayKey(Date()), forKey: Self.progressDateKey)
        defaults.set(processedToday, forKey: Self.progressCountKey)
    }

    private static func dayKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func folder(containing track: Track, folders: [LibraryFolder]) -> LibraryFolder? {
        let trackPath = track.fileURL.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        return folders.first { folder in
            let folderPath = folder.url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
            return trackPath == folderPath || trackPath.hasPrefix(folderPath + "/")
        }
    }
}
