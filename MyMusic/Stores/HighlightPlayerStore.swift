import Foundation
import Observation

@MainActor
@Observable
final class HighlightPlayerStore {
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var currentCandidate: HighlightCandidate?
    private(set) var analyzedTrackIDs: Set<Track.ID> = []
    private(set) var isAnalyzingCurrentTrack = false
    private(set) var isHighlightPlaybackActive = false
    private(set) var selectionMode: HighlightSelectionMode = .shuffle

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
    private let playbackHistoryStore: PlaybackHistoryStore
    private let trackFeatureStore: TrackFeatureStore
    private let analysisService: HighlightAnalysisServicing
    private var sourceTracks: [Track] = []
    private var candidatesByTrackID: [Track.ID: [HighlightCandidate]] = [:]
    private var startPlaybackTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var autoAdvanceTask: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var selectionGeneration = 0
    private var isSelectionPending = false
    private var playbackGeneration = UUID()
    private var hasPreparedRandomSelection = false
    private var preventsAutomaticAdvance = false

    init(
        playerStore: PlayerStore,
        playbackHistoryStore: PlaybackHistoryStore,
        trackFeatureStore: TrackFeatureStore,
        analysisService: HighlightAnalysisServicing = HighlightAnalysisService()
    ) {
        self.playerStore = playerStore
        self.playbackHistoryStore = playbackHistoryStore
        self.trackFeatureStore = trackFeatureStore
        self.analysisService = analysisService
    }

    func updateLibrary(_ tracks: [Track]) {
        let playableTracks = tracks.filter {
            $0.duration.isFinite && $0.duration > 1 && !$0.isEligibleForWorkPlayback
        }
        let previousIDs = Set(sourceTracks.map(\.id))
        sourceTracks = playableTracks
        let eligibleTracks = eligibleTracks(from: playableTracks)
        let currentIDs = Set(eligibleTracks.map(\.id))
        guard queue.isEmpty || previousIDs != Set(playableTracks.map(\.id)) else { return }

        if let currentTrack, currentIDs.contains(currentTrack.id) {
            queue = queue.filter { currentIDs.contains($0.id) }
            currentIndex = queue.firstIndex(where: { $0.id == currentTrack.id })
            let retained = currentIndex.map { Array(queue.prefix(through: $0)) } ?? []
            requestSelection(
                from: eligibleTracks, excluding: Set(retained.map(\.id)), precedingTracks: retained
            ) { [weak self] tracks in
                guard let self else { return }
                queue = retained + tracks
                currentIndex = queue.firstIndex(where: { $0.id == currentTrack.id })
                prefetchHighlights()
            }
        } else {
            rebuildQueueAndPlay(reason: .highlightAutomatic)
        }
    }

    func startIfNeeded() {
        if hasPreparedRandomSelection, currentTrack != nil {
            hasPreparedRandomSelection = false
            playCurrentTrack(reason: .highlightAutomatic)
            return
        }
        guard currentTrack == nil else { return }
        guard !isSelectionPending else { return }
        rebuildQueueAndPlay(reason: .highlightAutomatic)
    }

    /// Prepares a fresh random selection for the next visit without replacing
    /// playback that was started by another screen.
    func resetRandomSelection() {
        let previousTrackID = currentTrack?.id
        startPlaybackTask?.cancel()
        analysisTask?.cancel()
        autoAdvanceTask?.cancel()
        selectionTask?.cancel()
        selectionGeneration &+= 1
        isSelectionPending = false
        playbackGeneration = UUID()
        isAnalyzingCurrentTrack = false
        isHighlightPlaybackActive = false
        preventsAutomaticAdvance = false
        currentCandidate = nil
        requestSelection(from: sourceTracks) { [weak self] tracks in
            guard let self else { return }
            queue = avoidingFirst(previousTrackID, in: tracks)
            currentIndex = queue.isEmpty ? nil : 0
            hasPreparedRandomSelection = !queue.isEmpty
        }
    }

    func reshuffle() {
        rebuildQueueAndPlay(reason: .highlightUserInitiated)
    }

    func selectMode(_ mode: HighlightSelectionMode) {
        guard mode != selectionMode else { return }
        selectionMode = mode
        guard let currentIndex, queue.indices.contains(currentIndex) else {
            requestSelection(from: sourceTracks) { [weak self] tracks in
                guard let self else { return }
                queue = tracks
                currentIndex = queue.isEmpty ? nil : 0
            }
            return
        }
        let retained = Array(queue.prefix(through: currentIndex))
        let retainedIDs = Set(retained.map(\.id))
        requestSelection(
            from: sourceTracks, excluding: retainedIDs, precedingTracks: retained
        ) { [weak self] tracks in
            guard let self else { return }
            queue = retained + tracks
            self.currentIndex = retained.indices.last
            analysisTask?.cancel()
            prefetchHighlights()
        }
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
            rebuildQueueAndPlay(reason: userInitiated ? .highlightUserInitiated : .highlightAutomatic)
            return
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

    /// Keeps the current highlight playing while an editing sheet is open, but
    /// prevents its automatic transition from replacing the sheet's track.
    func beginPlaylistInteraction() {
        preventsAutomaticAdvance = true
    }

    func endPlaylistInteraction() {
        preventsAutomaticAdvance = false
    }

    func prepareFullPlayback() {
        guard let track = currentTrack else { return }
        startPlaybackTask?.cancel()
        analysisTask?.cancel()
        autoAdvanceTask?.cancel()
        selectionTask?.cancel()
        selectionGeneration &+= 1
        isSelectionPending = false
        playbackGeneration = UUID()
        isAnalyzingCurrentTrack = false
        isHighlightPlaybackActive = false
        preventsAutomaticAdvance = false
        let fullQueue = queue.isEmpty ? [track] : queue
        let index = fullQueue.firstIndex(where: { $0.id == track.id }) ?? 0
        playerStore.playQueue(
            fullQueue,
            startingAt: index,
            playbackStartTime: 0,
            transitionReason: .manualTrackChange,
            startContext: PlaybackStartContext(kind: .manual, source: .highlight)
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
        currentCandidate = nil
        hasPreparedRandomSelection = false
        preventsAutomaticAdvance = false
        let previousTrackID = currentTrack?.id
        requestSelection(from: sourceTracks) { [weak self] tracks in
            guard let self else { return }
            queue = avoidingFirst(previousTrackID, in: tracks)
            currentIndex = queue.isEmpty ? nil : 0
            guard !queue.isEmpty else {
                isHighlightPlaybackActive = false
                return
            }
            playCurrentTrack(reason: reason)
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
                transitionReason: reason,
                startContext: PlaybackStartContext(
                    kind: reason == .highlightAutomatic ? .automatic : .manual,
                    source: .highlight
                ),
                outgoingEndKind: reason == .highlightUserInitiated ? .userSkipped : .other
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
                    if preventsAutomaticAdvance {
                        isHighlightPlaybackActive = false
                        playerStore.pause()
                    } else {
                        playNext(userInitiated: false)
                    }
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

    private func eligibleTracks(from tracks: [Track]) -> [Track] {
        tracks.filter {
            $0.duration.isFinite && $0.duration > 1
                && playbackHistoryStore.isEligibleForRegularShuffle($0)
        }
    }

    private func requestSelection(
        from tracks: [Track],
        now: Date = Date(),
        excluding excludedIDs: Set<Track.ID> = [],
        precedingTracks: [Track] = [],
        apply: @escaping @MainActor ([Track]) -> Void
    ) {
        selectionTask?.cancel()
        selectionGeneration &+= 1
        isSelectionPending = true
        let generation = selectionGeneration
        let mode = selectionMode
        let eligible = tracks.filter {
            !excludedIDs.contains($0.id)
                && playbackHistoryStore.isEligibleForRegularShuffle($0, now: now)
        }
        let baseWeights = playbackHistoryStore.automaticSelectionWeights(for: eligible, now: now)
        let features = Dictionary(eligible.compactMap { track in
            trackFeatureStore.feature(for: track.id).map { (track.id, $0.values) }
        }, uniquingKeysWith: { first, _ in first })
        let histories = playbackHistoryStore.entries
        selectionTask = Task { [weak self] in
            let startedAt = ProcessInfo.processInfo.systemUptime
            let result = await Task.detached(priority: .userInitiated) {
                HighlightSelectionPolicy.selection(
                    eligible, mode: mode, baseWeights: baseWeights,
                    histories: histories, features: features, now: now,
                    precedingTracks: precedingTracks
                )
            }.value
            guard !Task.isCancelled, let self,
                  generation == selectionGeneration, mode == selectionMode else { return }
            isSelectionPending = false
#if DEBUG
            let elapsedMilliseconds = Int(
                ((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000).rounded()
            )
            print(
                "[HighlightSelection] mode=\(mode.rawValue) tracks=\(result.rankingCount) "
                    + "pool=\(result.candidatePoolCount) queue=\(result.tracks.count) "
                    + "comparisons=\(result.greedyComparisonCount) elapsed=\(elapsedMilliseconds)ms"
            )
#endif
            apply(result.tracks)
        }
    }

    private func avoidingFirst(_ trackID: Track.ID?, in tracks: [Track]) -> [Track] {
        var tracks = tracks
        if let trackID, tracks.count > 1, tracks.first?.id == trackID {
            tracks.swapAt(0, 1)
        }
        return tracks
    }

}
