import Foundation
import Observation

nonisolated struct ArtistRankingInput: Equatable, Sendable {
    let tracks: [Track]
    let histories: [Track.ID: PlaybackHistory]
    let preferences: [Track.ID: TrackPreference]
    let settings: ArtistRankingSettings
}

@MainActor
@Observable
final class ArtistRankingStore {
    private(set) var settings = ArtistRankingSettings()
    private(set) var pages: [ArtistRankingDivision: ArtistRankingPage] = [:]
    private(set) var isComputing = false
    private(set) var errorMessage: String?
    private var generation = 0
    private let defaults: UserDefaults
    private static let key = "ranking.artist-divisions.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.key) else { return }
        do { settings = try JSONDecoder().decode(ArtistRankingSettings.self, from: data) }
        catch { errorMessage = "部門設定を読み込めませんでした。保存し直すまで元のデータを保持します。" }
    }

    func save(_ draft: ArtistRankingSettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(draft)
            defaults.set(data, forKey: Self.key)
            settings = draft
            errorMessage = nil
            return true
        } catch {
            errorMessage = "部門設定を保存できませんでした。"
            return false
        }
    }

    func refresh(_ input: ArtistRankingInput) async {
        generation &+= 1
        let requestedGeneration = generation
        isComputing = true
        let work = Task.detached(priority: .userInitiated) {
            ArtistRankingService.pages(tracks: input.tracks, histories: input.histories,
                                       preferences: input.preferences, settings: input.settings)
        }
        let result = await withTaskCancellationHandler {
            await work.value
        } onCancel: {
            work.cancel()
        }
        guard !Task.isCancelled, generation == requestedGeneration else { return }
        pages = result
        isComputing = false
    }
}
