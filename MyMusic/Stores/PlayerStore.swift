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
    private var playbackTask: Task<Void, Never>?
    private var audioInformationTask: Task<Void, Never>?
    private var playbackRequestID = UUID()
    private var hasRecordedPlaybackStart = false
    private var hasCountedCurrentPlay = false
    private var listenedTime: TimeInterval = 0
    private var lastObservedPlaybackTime: TimeInterval?
    private var wasPlayingBeforeInterruption = false

    init(
        audioPlayer: AudioPlayerServicing? = nil,
        playbackHistoryStore: PlaybackHistoryStore? = nil,
        nowPlayingService: NowPlayingServicing? = nil,
        remoteCommandService: RemoteCommandServicing? = nil,
        audioInformationService: AudioInformationServicing?
    ) {
        let resolvedPlayer = audioPlayer ?? AudioPlayerService()
        self.audioPlayer = resolvedPlayer
        self.playbackHistoryStore = playbackHistoryStore ?? PlaybackHistoryStore()
        self.nowPlayingService = nowPlayingService ?? NowPlayingService()
        self.remoteCommandService = remoteCommandService ?? RemoteCommandService()
        self.audioInformationService = audioInformationService
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
        remoteCommandService: RemoteCommandServicing? = nil
    ) {
        self.init(
            audioPlayer: audioPlayer,
            playbackHistoryStore: playbackHistoryStore,
            nowPlayingService: nowPlayingService,
            remoteCommandService: remoteCommandService,
            audioInformationService: AudioInformationService()
        )
    }

    /// Starts a one-item queue for callers that do not provide playback context.
    func play(_ track: Track) {
        playQueue([track], startingAt: 0)
    }

    func playQueue(_ tracks: [Track], startingAt index: Int) {
        guard tracks.indices.contains(index) else {
            if tracks.isEmpty { stop() }
            return
        }
        queue = tracks
        currentIndex = nil
        rebuildPlaybackOrder(keepingCurrentIndex: index)
        startPlayback(at: index)
    }

    func playQueue(_ tracks: [Track], startingWith track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        playQueue(tracks, startingAt: index)
    }

    func playQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        startPlayback(at: index)
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
        queue = queue.enumerated().compactMap { index, track in
            indexesToRemove.contains(index) ? nil : track
        }
        playbackOrder = playbackOrder
            .filter { !indexesToRemove.contains($0) }
            .map { oldIndex in
                oldIndex - indexesToRemove.filter { $0 < oldIndex }.count
            }
        if let oldCurrentIndex {
            currentIndex = oldCurrentIndex - indexesToRemove.filter { $0 < oldCurrentIndex }.count
        }
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
        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            audioPlayer.pause()
            isPlaying = false
            nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: false)
            updateRemoteCommandAvailability()
            return
        }
        startPlayback(at: playbackOrder[nextPosition])
    }

    func previous() {
        guard let position = currentPlaybackPosition else { return }
        if currentTime >= previousRestartThreshold || position == 0 {
            seek(to: 0)
        } else {
            startPlayback(at: playbackOrder[position - 1])
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
        audioPlayer.seek(to: time)
        nowPlayingService.updatePlayback(elapsedTime: currentTime, isPlaying: isPlaying)
    }

    func stop() {
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
        audioInformation = .unknown
        spectrumLevels = Array(repeating: 0, count: 32)
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
        nowPlayingService.clear()
        updateRemoteCommandAvailability()
    }

    func dismissError() { errorMessage = nil }

    private func startPlayback(at index: Int) {
        guard queue.indices.contains(index), playbackOrder.contains(index) else { return }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        let track = queue[index]
        currentIndex = index
        currentTrack = track
        loadAudioInformation(for: track)
        resetPlaybackSession()
        currentTime = 0
        duration = track.duration
        isPlaying = false
        isLoading = true
        errorMessage = nil
        nowPlayingService.setTrack(track, duration: track.duration, elapsedTime: 0, isPlaying: false)
        updateRemoteCommandAvailability()

        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audioPlayer.play(track)
                guard playbackRequestID == requestID else { return }
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
            .filter { $0 != index && !playbackHistoryStore.isHiddenFromShuffle(trackID: queue[$0].id) }
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
            startPlayback(at: currentIndex)
            return
        }

        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            isPlaying = false
            return
        }
        startPlayback(at: playbackOrder[nextPosition])
    }

    private func handle(_ event: AudioPlaybackEvent) {
        switch event {
        case let .ready(duration):
            self.duration = duration
            isLoading = false
            nowPlayingService.updateDuration(duration, elapsedTime: currentTime, isPlaying: isPlaying)
        case let .timeChanged(time):
            let safeTime = time.isFinite ? time : 0
            recordListenedTime(at: safeTime)
            currentTime = safeTime
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
        let threshold = min(30, duration * 0.5)
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
