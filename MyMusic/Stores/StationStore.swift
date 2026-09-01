import Foundation
import Observation

@MainActor
@Observable
final class StationStore {
    enum Phase: Hashable { case mood, sound, refinement, decade, generating, result }

    private(set) var phase: Phase = .mood
    private(set) var mood: StationMood?
    private(set) var sound: StationSound?
    private(set) var refinement: StationRefinement?
    private(set) var direction: StationDirection?
    private(set) var decade: StationDecade?
    private(set) var station: MoodStation?
    private(set) var errorMessage: String?
    private var requestID = UUID()

    private let libraryStore: LibraryStore
    private let featureStore: TrackFeatureStore
    private let historyStore: PlaybackHistoryStore
    private let playerStore: PlayerStore
    private let service = MoodStationService()

    init(libraryStore: LibraryStore, featureStore: TrackFeatureStore,
         historyStore: PlaybackHistoryStore, playerStore: PlayerStore) {
        self.libraryStore = libraryStore
        self.featureStore = featureStore
        self.historyStore = historyStore
        self.playerStore = playerStore
    }

    var isLoading: Bool {
        !libraryStore.isInitialLoadComplete || libraryStore.isLoading || !featureStore.isLoaded
            || featureStore.isProcessing || !historyStore.isLoaded
    }

    var availableFeatureCount: Int { candidates.count }
    var availableDecades: [StationDecade] { service.availableDecades(in: candidates) }
    var hasLibraryTracks: Bool { !libraryStore.tracks.isEmpty }
    var featureLoadError: String? { featureStore.errorMessage }

    var stationTracks: [Track] {
        guard let station else { return [] }
        let byID = Dictionary(libraryStore.tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return station.trackIDs.compactMap { byID[$0] }.filter {
            historyStore.isEligibleForRegularShuffle($0) && featureStore.hasFeature($0.id)
        }
    }

    private var candidates: [StationCandidate] {
        let eligibleTracks = libraryStore.tracks.filter(historyStore.isEligibleForRegularShuffle)
        let overplayFactors = historyStore.stationOverplayFactors(for: eligibleTracks.map(\.id))
        return eligibleTracks.compactMap { track in
            guard let feature = featureStore.feature(for: track.id),
                  service.hasUsableFeatures(feature.values)
            else { return nil }
            return StationCandidate(
                trackID: track.id,
                artist: track.artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                year: track.year,
                values: feature.values,
                overplayFactor: overplayFactors[track.id] ?? 1
            )
        }
    }

    func prepare() async {
        await libraryStore.restoreAndLoadIfNeeded()
        await featureStore.loadIfNeeded()
        await historyStore.loadIfNeeded()
    }

    func begin() {
        requestID = UUID()
        mood = nil
        sound = nil
        refinement = nil
        direction = nil
        decade = nil
        errorMessage = nil
        phase = .mood
        // Keep the last station until a new one is successfully generated.
    }

    func chooseMood(_ value: StationMood) {
        mood = value
        sound = nil
        refinement = nil
        direction = nil
        decade = nil
        phase = .sound
    }

    func chooseSound(_ value: StationSound) {
        guard let mood else { return }
        sound = value
        direction = nil
        decade = nil
        refinement = service.followUp(for: StationAnswers(mood: mood, sound: value), candidates: candidates)
        phase = refinement == nil ? phaseAfterRefinement : .refinement
    }

    func chooseDirection(_ value: StationDirection?) {
        direction = value
        phase = phaseAfterRefinement
    }

    func chooseDecade(_ value: StationDecade?) {
        if let value, !availableDecades.contains(value) { return }
        decade = value
        phase = .generating
    }

    func goBack() {
        errorMessage = nil
        switch phase {
        case .sound: phase = .mood
        case .refinement: phase = .sound
        case .decade: phase = refinement == nil ? .sound : .refinement
        case .result:
            phase = availableDecades.isEmpty ? (refinement == nil ? .sound : .refinement) : .decade
        case .mood, .generating: break
        }
    }

    func generate() async {
        guard phase == .generating, let mood, let sound else { return }
        let request = UUID()
        requestID = request
        let answers = StationAnswers(
            mood: mood, sound: sound, refinement: refinement, direction: direction, decade: decade
        )
        let candidates = candidates
        let service = service
        let result = await Task.detached(priority: .userInitiated) {
            var generator = SystemRandomNumberGenerator()
            return service.makeStation(answers: answers, candidates: candidates, using: &generator)
        }.value
        guard requestID == request else { return }
        guard !Task.isCancelled else {
            phase = .sound
            return
        }
        if result.trackIDs.isEmpty {
            errorMessage = "この条件に近い曲が見つかりませんでした。年代や音の感じを変えるか、特徴量を追加して試してください。"
            phase = availableDecades.isEmpty ? .sound : .decade
            return
        }
        station = result
        errorMessage = nil
        phase = .result
    }

    /// Resolves IDs again so removed, hidden or excluded tracks never re-enter the queue.
    @discardableResult
    func play(startingWith trackID: Track.ID? = nil) -> Bool {
        guard !isLoading else { return false }
        let tracks = stationTracks
        guard !tracks.isEmpty else {
            errorMessage = "再生できる曲がありません。ステーションを作り直してください。"
            return false
        }
        let index: Int
        if let trackID {
            guard let found = tracks.firstIndex(where: { $0.id == trackID }) else { return false }
            index = found
        } else {
            index = 0
        }
        playerStore.setShuffleEnabled(false)
        playerStore.playQueue(
            tracks,
            startingAt: index,
            startContext: PlaybackStartContext(kind: .manual, source: .station)
        )
        return true
    }

    private var phaseAfterRefinement: Phase {
        availableDecades.isEmpty ? .generating : .decade
    }
}
