import Foundation
import Observation

@MainActor
@Observable
final class HighlightPlayerStore {
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var currentCandidate: HighlightCandidate?
    private(set) var availableGenres: [String] = []
    private(set) var selectedGenre: String?
    private(set) var analyzedTrackIDs: Set<Track.ID> = []
    private(set) var isAnalyzingCurrentTrack = false
    private(set) var isHighlightPlaybackActive = false

    var currentTrack: Track? {
        guard let currentIndex, queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    var currentCandidateNumber: Int {
        guard let currentTrack, let currentCandidate else { return 0 }
        return (candidates(for: currentTrack).firstIndex(of: currentCandidate) ?? -1) + 1
    }

    var currentCandidateCount: Int {
        currentTrack.map { candidates(for: $0).count } ?? 0
    }

    private let playerStore: PlayerStore
    private let analysisService: HighlightAnalysisServicing
    private var sourceTracks: [Track] = []
    private var candidatesByTrackID: [Track.ID: [HighlightCandidate]] = [:]
    private var startPlaybackTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var playbackGeneration = UUID()

    init(
        playerStore: PlayerStore,
        analysisService: HighlightAnalysisServicing = HighlightAnalysisService()
    ) {
        self.playerStore = playerStore
        self.analysisService = analysisService
    }

    func updateLibrary(_ tracks: [Track]) {
        let playableTracks = tracks.filter { $0.duration.isFinite && $0.duration > 1 }
        let previousIDs = Set(sourceTracks.map(\.id))
        sourceTracks = playableTracks
        availableGenres = Self.genreNames(in: playableTracks).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        if let selectedGenre, !availableGenres.contains(selectedGenre) {
            self.selectedGenre = nil
        }
        let currentIDs = Set(playableTracks.map(\.id))
        guard queue.isEmpty || previousIDs != currentIDs else { return }

        if let currentTrack, currentIDs.contains(currentTrack.id) {
            queue = queue.filter { currentIDs.contains($0.id) }
            currentIndex = queue.firstIndex(where: { $0.id == currentTrack.id })
        } else {
            rebuildQueueAndPlay(reason: .highlightAutomatic)
        }
    }

    func startIfNeeded() {
        guard currentTrack == nil else { return }
        rebuildQueueAndPlay(reason: .highlightAutomatic)
    }

    func selectGenre(_ genre: String?) {
        guard selectedGenre != genre else { return }
        selectedGenre = genre
        rebuildQueueAndPlay(reason: .highlightUserInitiated)
    }

    func reshuffle() {
        rebuildQueueAndPlay(reason: .highlightUserInitiated)
    }

    func move(to trackID: Track.ID) {
        guard let index = queue.firstIndex(where: { $0.id == trackID }), index != currentIndex else { return }
        currentIndex = index
        playCurrentTrack(reason: .highlightUserInitiated)
    }

    func playNext(userInitiated: Bool) {
        guard !queue.isEmpty else { return }
        if let currentIndex, queue.indices.contains(currentIndex + 1) {
            self.currentIndex = currentIndex + 1
        } else {
            reshuffleQueue(avoidingFirstTrackID: currentTrack?.id)
            currentIndex = queue.isEmpty ? nil : 0
        }
        playCurrentTrack(reason: userInitiated ? .highlightUserInitiated : .highlightAutomatic)
    }

    func playPrevious() {
        guard let currentIndex, currentIndex > 0 else { return }
        self.currentIndex = currentIndex - 1
        playCurrentTrack(reason: .highlightUserInitiated)
    }

    func playAnotherPart() {
        guard let track = currentTrack,
              playerStore.currentTrack?.id == track.id,
              !playerStore.isLoading else { return }
        let trackCandidates = candidates(for: track)
        guard !trackCandidates.isEmpty else { return }
        let currentCandidateIndex = currentCandidate.flatMap { trackCandidates.firstIndex(of: $0) }
        let nextIndex = currentCandidateIndex.map { ($0 + 1) % trackCandidates.count } ?? 0
        let candidate = trackCandidates[nextIndex]
        currentCandidate = candidate
        playbackGeneration = UUID()
        isHighlightPlaybackActive = true
        playerStore.seekWithTransition(
            to: candidate.startTime,
            endingAt: candidate.endTime,
            reason: .highlightUserInitiated
        )
        restartAutoAdvance(for: track, candidate: candidate)
    }

    func prepareFullPlayback() {
        guard let track = currentTrack else { return }
        startPlaybackTask?.cancel()
        analysisTask?.cancel()
        autoAdvanceTask?.cancel()
        playbackGeneration = UUID()
        isAnalyzingCurrentTrack = false
        isHighlightPlaybackActive = false
        let fullQueue = queue.isEmpty ? [track] : queue
        let index = fullQueue.firstIndex(where: { $0.id == track.id }) ?? 0
        playerStore.playQueue(
            fullQueue,
            startingAt: index,
            playbackStartTime: 0,
            transitionReason: .manualTrackChange
        )
    }

    func resumeHighlightPlayback() {
        playCurrentTrack(reason: .highlightUserInitiated)
    }

    func candidate(for track: Track) -> HighlightCandidate {
        if track.id == currentTrack?.id, let currentCandidate { return currentCandidate }
        return candidates(for: track).first
            ?? HighlightCandidate.fallbackCandidates(trackDuration: track.duration).first
            ?? HighlightCandidate(startTime: 0, duration: min(track.duration, 30), score: 0)
    }

    private func candidates(for track: Track) -> [HighlightCandidate] {
        candidatesByTrackID[track.id]
            ?? HighlightCandidate.fallbackCandidates(
                trackDuration: track.duration,
                highlightDuration: HighlightAnalysisService.highlightDuration
            )
    }

    private func rebuildQueueAndPlay(reason: PlaybackTransitionReason) {
        autoAdvanceTask?.cancel()
        startPlaybackTask?.cancel()
        analysisTask?.cancel()
        let filteredTracks = sourceTracks.filter { track in
            guard let selectedGenre else { return true }
            return Self.genreNames(in: track.genre).contains(selectedGenre)
        }
        queue = filteredTracks.shuffled()
        currentIndex = queue.isEmpty ? nil : 0
        currentCandidate = nil
        guard !queue.isEmpty else {
            isHighlightPlaybackActive = false
            return
        }
        playCurrentTrack(reason: reason)
    }

    private func reshuffleQueue(avoidingFirstTrackID trackID: Track.ID?) {
        let filteredTracks = sourceTracks.filter { track in
            guard let selectedGenre else { return true }
            return Self.genreNames(in: track.genre).contains(selectedGenre)
        }
        queue = filteredTracks.shuffled()
        if let trackID, queue.count > 1, queue.first?.id == trackID {
            queue.swapAt(0, 1)
        }
    }

    private func playCurrentTrack(reason: PlaybackTransitionReason) {
        guard let track = currentTrack else { return }
        playbackGeneration = UUID()
        let generation = playbackGeneration
        let fallback = candidates(for: track).first
            ?? HighlightCandidate(startTime: 0, duration: min(track.duration, 30), score: 0)
        currentCandidate = fallback
        isAnalyzingCurrentTrack = !analyzedTrackIDs.contains(track.id)

        startPlaybackTask?.cancel()
        startPlaybackTask = Task { [weak self, analysisService] in
            let cached = await analysisService.cachedHighlights(for: track)
            guard !Task.isCancelled, let self, playbackGeneration == generation else { return }
            let candidate: HighlightCandidate
            if let cached {
                candidatesByTrackID[track.id] = cached.candidates
                analyzedTrackIDs.insert(track.id)
                isAnalyzingCurrentTrack = false
                candidate = cached.candidates.first ?? fallback
            } else {
                candidate = fallback
            }
            currentCandidate = candidate
            isHighlightPlaybackActive = true
            playerStore.setShuffleEnabled(false)
            playerStore.playQueue(
                [track],
                startingAt: 0,
                playbackStartTime: candidate.startTime,
                playbackEndTime: candidate.endTime,
                transitionReason: reason
            )
            restartAutoAdvance(for: track, candidate: candidate)
            prefetchHighlights()
        }
    }

    private func restartAutoAdvance(for track: Track, candidate: HighlightCandidate) {
        autoAdvanceTask?.cancel()
        let generation = playbackGeneration
        autoAdvanceTask = Task { [weak self] in
            var listenedTime: TimeInterval = 0
            var previousTime = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled, let self, playbackGeneration == generation else { return }
                let now = ProcessInfo.processInfo.systemUptime
                defer { previousTime = now }
                guard isHighlightPlaybackActive,
                      playerStore.currentTrack?.id == track.id,
                      playerStore.isPlaying else { continue }
                listenedTime += now - previousTime
                if listenedTime >= candidate.duration {
                    playNext(userInitiated: false)
                    return
                }
            }
        }
    }

    private func prefetchHighlights() {
        analysisTask?.cancel()
        guard let currentIndex else { return }
        let endIndex = min(currentIndex + 5, queue.index(before: queue.endIndex))
        let tracksToAnalyze = Array(queue[currentIndex...endIndex])
        let activeTrackID = currentTrack?.id
        isAnalyzingCurrentTrack = activeTrackID.map { !analyzedTrackIDs.contains($0) } ?? false

        analysisTask = Task { [weak self, analysisService] in
            for track in tracksToAnalyze {
                guard !Task.isCancelled else { return }
                let result = await analysisService.highlights(for: track)
                guard !Task.isCancelled, let self else { return }
                candidatesByTrackID[track.id] = result.candidates
                analyzedTrackIDs.insert(track.id)
                if track.id == activeTrackID { isAnalyzingCurrentTrack = false }
            }
        }
    }

    private static func genreNames(in tracks: [Track]) -> Set<String> {
        tracks.reduce(into: Set<String>()) { result, track in
            result.formUnion(genreNames(in: track.genre))
        }
    }

    private static func genreNames(in value: String?) -> Set<String> {
        guard let value else { return [] }
        return Set(value
            .split(whereSeparator: { $0 == ";" || $0 == "\0" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }
}
