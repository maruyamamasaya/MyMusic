import Foundation
import Observation

enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

enum PlayerPresentationMode: Sendable, Equatable {
    case standard
    case workSize
}

@MainActor
@Observable
final class PlayerStore {
    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var playbackOrder: [Int] = []
    private(set) var isShuffleEnabled = false
    private(set) var repeatMode: RepeatMode = .off
    private(set) var presentationMode: PlayerPresentationMode = .standard
    private(set) var audioInformation = AudioInformation.unknown
    private(set) var spectrumLevels: [Float] = Array(repeating: 0, count: 32)

    var hasNext: Bool {
        guard currentPlaybackPosition != nil else { return false }
        return nextPlaybackPosition(wrapping: repeatMode == .all) != nil
    }

    var hasPrevious: Bool {
        guard let position = currentPlaybackPosition else { return false }
        return currentTime > 0 || position > 0
    }

    private var currentPlaybackPosition: Int? {
        guard let currentIndex else { return nil }
        return playbackOrder.firstIndex(of: currentIndex)
    }

    private let previousRestartThreshold: TimeInterval = 3
    private let audioPlayer: AudioPlayerServicing
    private let playbackHistoryStore: PlaybackHistoryStore
    private let nowPlayingService: NowPlayingServicing
    private let remoteCommandService: RemoteCommandServicing
    private let audioInformationService: AudioInformationServicing?
    private let trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore
    private let normalizationMetadataProvider: (Track.ID) async -> TrackNormalizationMetadata?
    private var playbackTask: Task<Void, Never>?
    private var audioInformationTask: Task<Void, Never>?
    private var playbackRequestID = UUID()
    private var hasRecordedPlaybackStart = false
    private var hasCountedCurrentPlay = false
    private var listenedTime: TimeInterval = 0
    private var lastObservedPlaybackTime: TimeInterval?
    private var playbackCountThresholdOverride: TimeInterval?
    private var wasPlayingBeforeInterruption = false
    private var activeCustomEndPosition: TimeInterval?
    private var usesTrackAdjustmentBoundaries = false
    private var isCompletingCustomEnd = false
    private var lastPositionPersistenceDate = Date.distantPast
    private let periodicPositionPersistenceInterval: TimeInterval = 7

    init(
        audioPlayer: AudioPlayerServicing? = nil,
        playbackHistoryStore: PlaybackHistoryStore? = nil,
        nowPlayingService: NowPlayingServicing? = nil,
        remoteCommandService: RemoteCommandServicing? = nil,
        audioInformationService: AudioInformationServicing?,
        trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore? = nil,
        normalizationMetadataProvider: @escaping (Track.ID) async -> TrackNormalizationMetadata? = { _ in nil }
    ) {
        let resolvedPlayer = audioPlayer ?? AudioPlayerService()
        self.audioPlayer = resolvedPlayer
        self.playbackHistoryStore = playbackHistoryStore ?? PlaybackHistoryStore()
        self.nowPlayingService = nowPlayingService ?? NowPlayingService()
        self.remoteCommandService = remoteCommandService ?? RemoteCommandService()
        self.audioInformationService = audioInformationService
        self.trackPlaybackAdjustmentStore = trackPlaybackAdjustmentStore ?? TrackPlaybackAdjustmentStore()
        self.normalizationMetadataProvider = normalizationMetadataProvider
        resolvedPlayer.eventHandler = { [weak self] event in
            self?.handle(event)
        }
        (resolvedPlayer as? EqualizerControlling)?.spectrumHandler = { [weak self] levels in
            self?.spectrumLevels = levels
        }
        self.audioInformationService?.outputChangeHandler = { [weak self] name, sampleRate in
            self?.audioInformation.outputName = name
            self?.audioInformation.outputSampleRate = sampleRate
        }
        self.remoteCommandService.configure(actions: RemoteCommandActions(
            play: { [weak self] in self?.resume() },
            pause: { [weak self] in self?.pause() },
            togglePlayPause: { [weak self] in self?.togglePlayPause() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            seek: { [weak self] time in self?.seek(to: time) }
        ))
        updateRemoteCommandAvailability()
    }

    convenience init(
        audioPlayer: AudioPlayerServicing? = nil,
        playbackHistoryStore: PlaybackHistoryStore? = nil,
        nowPlayingService: NowPlayingServicing? = nil,
        remoteCommandService: RemoteCommandServicing? = nil,
        trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore? = nil,
        normalizationMetadataProvider: @escaping (Track.ID) async -> TrackNormalizationMetadata? = { _ in nil }
    ) {
        self.init(
            audioPlayer: audioPlayer,
            playbackHistoryStore: playbackHistoryStore,
            nowPlayingService: nowPlayingService,
            remoteCommandService: remoteCommandService,
            audioInformationService: AudioInformationService(),
            trackPlaybackAdjustmentStore: trackPlaybackAdjustmentStore,
            normalizationMetadataProvider: normalizationMetadataProvider
        )
    }

    convenience init(
        audioPlayer: AudioPlayerServicing? = nil,
        playbackHistoryStore: PlaybackHistoryStore? = nil,
        nowPlayingService: NowPlayingServicing? = nil,
        remoteCommandService: RemoteCommandServicing? = nil,
        normalizationGainProvider: @escaping (Track.ID) -> Double?
    ) {
        self.init(
            audioPlayer: audioPlayer,
            playbackHistoryStore: playbackHistoryStore,
            nowPlayingService: nowPlayingService,
            remoteCommandService: remoteCommandService,
            audioInformationService: AudioInformationService(),
            normalizationMetadataProvider: { trackID in
                TrackNormalizationMetadata(
                    automaticGainDB: normalizationGainProvider(trackID),
                    truePeakDBTP: nil
                )
            }
        )
    }

    /// Starts a one-item queue for callers that do not provide playback context.
    func play(_ track: Track) {
        playQueue([track], startingAt: 0)
    }

    func playQueue(
        _ tracks: [Track],
        startingAt index: Int,
        playbackStartTime: TimeInterval = 0,
        playbackEndTime: TimeInterval? = nil,
        transitionReason: PlaybackTransitionReason = .manualTrackChange,
        presentationMode: PlayerPresentationMode = .standard
    ) {
        guard tracks.indices.contains(index) else {
            if tracks.isEmpty { stop() }
            return
        }
        self.presentationMode = presentationMode
        queue = tracks
        currentIndex = nil
        rebuildPlaybackOrder(keepingCurrentIndex: index)
        startPlayback(
            at: index,
            playbackStartTime: playbackStartTime,
            playbackEndTime: playbackEndTime,
            transitionReason: transitionReason
        )
    }

    func playQueue(_ tracks: [Track], startingWith track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        playQueue(tracks, startingAt: index)
    }

    func playQueueItem(
        at index: Int,
        playbackStartTime: TimeInterval = 0,
        playbackEndTime: TimeInterval? = nil,
        transitionReason: PlaybackTransitionReason = .manualTrackChange
    ) {
        guard queue.indices.contains(index) else { return }
        startPlayback(
            at: index,
            playbackStartTime: playbackStartTime,
            playbackEndTime: playbackEndTime,
            transitionReason: transitionReason
        )
    }

    /// Removes queue entries at positions in the currently displayed playback order.
    /// The track that is currently playing is intentionally kept in the queue.
    func removeQueueItems(atOffsets offsets: IndexSet) {
        let indexesToRemove: Set<Int> = Set(offsets.compactMap { position -> Int? in
            guard playbackOrder.indices.contains(position) else { return nil }
            let queueIndex = playbackOrder[position]
            return queueIndex == currentIndex ? nil : queueIndex
        })
        guard !indexesToRemove.isEmpty else { return }

        let oldCurrentIndex = currentIndex
        let updatedQueue = queue.enumerated().compactMap { index, track in
            indexesToRemove.contains(index) ? nil : track
        }
        let updatedPlaybackOrder = playbackOrder
            .filter { !indexesToRemove.contains($0) }
            .map { oldIndex in
                oldIndex - indexesToRemove.filter { $0 < oldIndex }.count
            }
        let updatedCurrentIndex = oldCurrentIndex.map { index in
            index - indexesToRemove.filter { $0 < index }.count
        }

        // Keep every published playback-order index valid while Observation
        // delivers these individual state changes to SwiftUI.
        playbackOrder = updatedPlaybackOrder
        currentIndex = updatedCurrentIndex
        queue = updatedQueue
        updateRemoteCommandAvailability()
    }

    /// Moves queue entries using positions from the currently displayed playback order.
    func moveQueueItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        let validSource = source.filter { playbackOrder.indices.contains($0) }
        guard !validSource.isEmpty else { return }

        let movedIndexes = validSource.sorted().map { playbackOrder[$0] }
        var reorderedIndexes = playbackOrder.enumerated()
            .filter { !validSource.contains($0.offset) }
            .map(\.element)
        let insertionIndex = min(
            max(destination - validSource.filter { $0 < destination }.count, 0),
            reorderedIndexes.count
        )
        reorderedIndexes.insert(contentsOf: movedIndexes, at: insertionIndex)

        let oldCurrentIndex = currentIndex
        queue = reorderedIndexes.map { queue[$0] }
        currentIndex = oldCurrentIndex.flatMap { reorderedIndexes.firstIndex(of: $0) }
        playbackOrder = Array(queue.indices)
        updateRemoteCommandAvailability()
    }

    func next() {
        next(using: .manualTrackChange)
    }

    func next(using transitionReason: PlaybackTransitionReason) {
        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            persistCurrentPlaybackPosition(force: true)
            audioPlayer.pause()
            isPlaying = false
            nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: false)
            updateRemoteCommandAvailability()
            return
        }
        startPlayback(at: playbackOrder[nextPosition], transitionReason: transitionReason)
    }

    func previous() {
        guard let position = currentPlaybackPosition else { return }
        if currentTime >= previousRestartThreshold || position == 0 {
            seek(to: currentTrack.map { effectiveStartPosition(for: $0) } ?? 0)
        } else {
            startPlayback(at: playbackOrder[position - 1], transitionReason: .manualTrackChange)
        }
    }

    func toggleShuffle() {
        setShuffleEnabled(!isShuffleEnabled)
    }

    func setShuffleEnabled(_ isEnabled: Bool) {
        guard isShuffleEnabled != isEnabled else { return }
        isShuffleEnabled = isEnabled
        rebuildPlaybackOrder(keepingCurrentIndex: currentIndex)
        updateRemoteCommandAvailability()
    }

    func refreshShuffleExclusions() {
        guard isShuffleEnabled else { return }
        rebuildPlaybackOrder(keepingCurrentIndex: currentIndex)
        updateRemoteCommandAvailability()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
        updateRemoteCommandAvailability()
    }

    func pause() {
        persistCurrentPlaybackPosition(force: true)
        audioPlayer.pause()
    }

    func resume() {
        guard currentTrack != nil else { return }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        isLoading = true
        errorMessage = nil
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audioPlayer.resume()
            } catch is CancellationError {
                return
            } catch {
                guard playbackRequestID == requestID else { return }
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            if playbackRequestID == requestID { isLoading = false }
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(to time: TimeInterval) {
        let upperBound = activeCustomEndPosition ?? duration
        audioPlayer.seek(to: min(max(time.isFinite ? time : 0, 0), max(upperBound, 0)))
        nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: isPlaying)
    }

    func skip(by offset: TimeInterval) {
        seek(to: min(max(currentTime + offset, 0), duration))
    }

    /// Intended for responsive highlight changes such as 「別の部分」.
    /// Repeated calls cancel the preceding transition before starting a new one.
    func seekWithTransition(
        to time: TimeInterval,
        endingAt playbackEndTime: TimeInterval? = nil,
        reason: PlaybackTransitionReason = .highlightUserInitiated
    ) {
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let transitionPlayer = audioPlayer as? PlaybackTransitionAudioControlling {
                    try await transitionPlayer.seek(
                        to: time,
                        endingAt: playbackEndTime,
                        transition: reason
                    )
                } else {
                    audioPlayer.seek(to: time)
                }
                guard playbackRequestID == requestID else { return }
                nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: isPlaying)
            } catch is CancellationError {
                return
            } catch {
                guard playbackRequestID == requestID else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Highlight playback can set its segment end here so fade-out starts at
    /// `highlightEndTime - fadeOutDuration` without duplicating fade logic.
    func scheduleFadeOut(endingAt playbackTime: TimeInterval, reason: PlaybackTransitionReason = .highlightAutomatic) {
        (audioPlayer as? PlaybackTransitionAudioControlling)?
            .scheduleFadeOut(endingAt: playbackTime, reason: reason)
    }

    func stop() {
        persistCurrentPlaybackPosition(force: true)
        playbackTask?.cancel()
        audioInformationTask?.cancel()
        playbackTask = nil
        audioInformationTask = nil
        playbackRequestID = UUID()
        audioPlayer.stop()
        queue = []
        playbackOrder = []
        currentIndex = nil
        currentTrack = nil
        presentationMode = .standard
        audioInformation = .unknown
        spectrumLevels = Array(repeating: 0, count: 32)
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
        activeCustomEndPosition = nil
        usesTrackAdjustmentBoundaries = false
        isCompletingCustomEnd = false
        nowPlayingService.clear()
        updateRemoteCommandAvailability()
    }

    func dismissError() { errorMessage = nil }

    /// Flushes the current position at lifecycle boundaries without coupling
    /// persistence to a view timer.
    func persistPlaybackPositionForLifecycle() {
        persistCurrentPlaybackPosition(force: true)
    }

    func refreshActiveTrackAdjustment() {
        guard let track = currentTrack else { return }
        validateActiveAdjustment(for: duration > 0 ? duration : track.duration)
    }

    private func startPlayback(
        at index: Int,
        playbackStartTime: TimeInterval = 0,
        playbackEndTime: TimeInterval? = nil,
        transitionReason: PlaybackTransitionReason,
        savesPreviousPosition: Bool = true
    ) {
        guard queue.indices.contains(index), playbackOrder.contains(index) else { return }
        if savesPreviousPosition { persistCurrentPlaybackPosition(force: true) }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        let track = queue[index]
        currentIndex = index
        currentTrack = track
        loadAudioInformation(for: track)
        resetPlaybackSession()
        playbackCountThresholdOverride = playbackEndTime == nil ? nil : 15
        currentTime = playbackStartTime
        duration = track.duration
        activeCustomEndPosition = nil
        usesTrackAdjustmentBoundaries = playbackEndTime == nil
        isCompletingCustomEnd = false
        lastPositionPersistenceDate = Date()
        isPlaying = false
        isLoading = true
        errorMessage = nil
        nowPlayingService.setTrack(
            track,
            duration: track.duration,
            elapsedTime: playbackStartTime,
            isPlaying: false
        )
        updateRemoteCommandAvailability()

        playbackTask = Task { [weak self] in
            guard let self else { return }
            let adjustment = await trackPlaybackAdjustmentStore.load(
                for: track.id,
                duration: track.duration
            )
            let normalizationMetadata = await normalizationMetadataProvider(track.id)
            guard playbackRequestID == requestID, !Task.isCancelled else { return }

            let usesTrackBoundaries = playbackEndTime == nil
            let resolvedStartTime: TimeInterval
            if usesTrackBoundaries, playbackStartTime == 0 {
                resolvedStartTime = adjustment.customStartPosition ?? 0
            } else {
                resolvedStartTime = playbackStartTime
            }
            activeCustomEndPosition = usesTrackBoundaries ? adjustment.customEndPosition : nil
            let finalGain = VolumeNormalizationGain.finalDecibels(
                automaticGainDB: normalizationMetadata?.automaticGainDB,
                manualAdjustmentDB: adjustment.manualNormalizationAdjustmentDB,
                truePeakDBTP: normalizationMetadata?.truePeakDBTP
            )
            (audioPlayer as? VolumeNormalizationControlling)?.prepareVolumeNormalizationGain(
                decibels: finalGain
            )
            currentTime = resolvedStartTime
            nowPlayingService.setTrack(
                track,
                duration: track.duration,
                elapsedTime: resolvedStartTime,
                isPlaying: false
            )
            do {
                if let transitionPlayer = audioPlayer as? PlaybackTransitionAudioControlling {
                    try await transitionPlayer.play(
                        track,
                        startingAt: resolvedStartTime,
                        endingAt: playbackEndTime,
                        transition: transitionReason
                    )
                } else {
                    try await audioPlayer.play(track)
                }
                guard playbackRequestID == requestID else { return }
                if let customEnd = activeCustomEndPosition {
                    (audioPlayer as? PlaybackTransitionAudioControlling)?.scheduleFadeOut(
                        endingAt: customEnd,
                        reason: .automaticTrackChange
                    )
                }
                recordPlaybackStartIfNeeded()
            } catch is CancellationError {
                return
            } catch {
                guard playbackRequestID == requestID else { return }
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            if playbackRequestID == requestID { isLoading = false }
        }
    }

    private func beginPlaybackRequest() -> UUID {
        let requestID = UUID()
        playbackRequestID = requestID
        return requestID
    }

    private func loadAudioInformation(for track: Track) {
        audioInformationTask?.cancel()
        audioInformation = .unknown
        guard let audioInformationService else { return }
        audioInformationTask = Task { [weak self] in
            let information = await audioInformationService.information(for: track)
            guard !Task.isCancelled, self?.currentTrack?.id == track.id else { return }
            self?.audioInformation = information
        }
    }

    private func rebuildPlaybackOrder(keepingCurrentIndex index: Int?) {
        let naturalOrder = Array(queue.indices)
        guard isShuffleEnabled, let index, queue.indices.contains(index) else {
            playbackOrder = naturalOrder
            return
        }
        let weightedIndexes = naturalOrder
            .filter {
                $0 != index
                    && playbackHistoryStore.isEligibleForRegularShuffle(queue[$0])
            }
            .map { queueIndex in
                let unitRandom = Double.random(in: Double.leastNonzeroMagnitude ... 1)
                let weight = playbackHistoryStore.playbackSelectionWeight(for: queue[queueIndex].id)
                return (index: queueIndex, key: -log(unitRandom) / weight)
            }
            .sorted { $0.key < $1.key }
            .map(\.index)
        playbackOrder = [index] + weightedIndexes
    }

    private func nextPlaybackPosition(wrapping: Bool) -> Int? {
        guard let position = currentPlaybackPosition, !playbackOrder.isEmpty else { return nil }
        let nextPosition = position + 1
        if playbackOrder.indices.contains(nextPosition) { return nextPosition }
        return wrapping ? playbackOrder.startIndex : nil
    }

    private func advanceAfterTrackEnded() {
        if repeatMode == .one, let currentIndex {
            startPlayback(
                at: currentIndex,
                transitionReason: .automaticTrackChange,
                savesPreviousPosition: false
            )
            return
        }

        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            isPlaying = false
            return
        }
        startPlayback(
            at: playbackOrder[nextPosition],
            transitionReason: .automaticTrackChange,
            savesPreviousPosition: false
        )
    }

    private func handle(_ event: AudioPlaybackEvent) {
        switch event {
        case let .ready(duration):
            self.duration = duration
            isLoading = false
            nowPlayingService.updateDuration(duration, elapsedTime: currentTime, isPlaying: isPlaying)
            validateActiveAdjustment(for: duration)
        case let .timeChanged(time):
            let safeTime = time.isFinite ? time : 0
            recordListenedTime(at: safeTime)
            currentTime = safeTime
            if let customEnd = activeCustomEndPosition,
               safeTime >= customEnd,
               !isCompletingCustomEnd {
                completeCurrentTrack(at: customEnd)
            } else {
                persistCurrentPlaybackPosition(force: false)
            }
        case let .playingChanged(isPlaying):
            self.isPlaying = isPlaying
            if isPlaying { recordPlaybackStartIfNeeded() }
            lastObservedPlaybackTime = isPlaying ? currentTime : nil
            nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: isPlaying)
            updateRemoteCommandAvailability()
        case .ended:
            isPlaying = false
            currentTime = duration
            nowPlayingService.updatePlayback(elapsedTime: duration, isPlaying: false)
            persistCompletedTrackPosition()
            advanceAfterTrackEnded()
            updateRemoteCommandAvailability()
        case let .failed(message):
            isPlaying = false
            isLoading = false
            errorMessage = message
            nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: false)
        case .interruptionBegan:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying { pause() }
        case let .interruptionEnded(shouldResume):
            if shouldResume, wasPlayingBeforeInterruption { resume() }
            wasPlayingBeforeInterruption = false
        case .oldAudioDeviceUnavailable:
            if isPlaying { pause() }
        }
    }

    private func resetPlaybackSession() {
        hasRecordedPlaybackStart = false
        hasCountedCurrentPlay = false
        listenedTime = 0
        lastObservedPlaybackTime = nil
        playbackCountThresholdOverride = nil
    }

    private func effectiveStartPosition(for track: Track) -> TimeInterval {
        trackPlaybackAdjustmentStore.adjustment(for: track.id)
            .sanitized(for: duration > 0 ? duration : track.duration)
            .customStartPosition ?? 0
    }

    private func validateActiveAdjustment(for resolvedDuration: TimeInterval) {
        guard usesTrackAdjustmentBoundaries, let track = currentTrack else { return }
        let adjustment = trackPlaybackAdjustmentStore.adjustment(for: track.id)
            .sanitized(for: resolvedDuration)
        activeCustomEndPosition = adjustment.customEndPosition
        scheduleFadeOut(
            endingAt: activeCustomEndPosition ?? resolvedDuration,
            reason: .automaticTrackChange
        )
        Task { [weak self, trackPlaybackAdjustmentStore] in
            let persisted = await trackPlaybackAdjustmentStore.load(
                for: track.id,
                duration: resolvedDuration
            )
            guard let self,
                  self.currentTrack?.id == track.id,
                  self.usesTrackAdjustmentBoundaries else { return }
            self.activeCustomEndPosition = persisted.customEndPosition
            self.scheduleFadeOut(
                endingAt: persisted.customEndPosition ?? resolvedDuration,
                reason: .automaticTrackChange
            )
        }
    }

    private func completeCurrentTrack(at endPosition: TimeInterval) {
        isCompletingCustomEnd = true
        audioPlayer.pause()
        isPlaying = false
        currentTime = endPosition
        nowPlayingService.updatePlayback(elapsedTime: endPosition, isPlaying: false)
        persistCompletedTrackPosition()
        advanceAfterTrackEnded()
        updateRemoteCommandAvailability()
    }

    private func persistCompletedTrackPosition() {
        guard let track = currentTrack else { return }
        let resolvedDuration = duration > 0 ? duration : track.duration
        Task { [trackPlaybackAdjustmentStore] in
            await trackPlaybackAdjustmentStore.setLastPlaybackPosition(
                trackID: track.id,
                position: 0,
                duration: resolvedDuration
            )
        }
    }

    private func persistCurrentPlaybackPosition(force: Bool) {
        guard let track = currentTrack else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastPositionPersistenceDate) >= periodicPositionPersistenceInterval else {
            return
        }
        lastPositionPersistenceDate = now
        let position = currentTime
        let resolvedDuration = duration > 0 ? duration : track.duration
        Task { [trackPlaybackAdjustmentStore] in
            await trackPlaybackAdjustmentStore.setLastPlaybackPosition(
                trackID: track.id,
                position: position,
                duration: resolvedDuration
            )
        }
    }

    private func recordPlaybackStartIfNeeded() {
        guard let currentTrack, !hasRecordedPlaybackStart else { return }
        playbackHistoryStore.recordPlaybackStarted(trackID: currentTrack.id)
        hasRecordedPlaybackStart = true
    }

    private func recordListenedTime(at time: TimeInterval) {
        defer { lastObservedPlaybackTime = isPlaying ? time : nil }
        guard isPlaying, !hasCountedCurrentPlay, let previous = lastObservedPlaybackTime else { return }
        let delta = time - previous
        guard delta > 0, delta <= 1.5 else { return }
        listenedTime += delta
        let threshold = playbackCountThresholdOverride ?? min(30, duration * 0.5)
        guard threshold > 0, listenedTime >= threshold, let currentTrack else { return }
        playbackHistoryStore.recordPlaybackCompleted(trackID: currentTrack.id)
        hasCountedCurrentPlay = true
    }

    private func updateRemoteCommandAvailability() {
        remoteCommandService.updateAvailability(
            hasTrack: currentTrack != nil,
            canGoNext: hasNext,
            canGoPrevious: currentTrack != nil
        )
    }
}
