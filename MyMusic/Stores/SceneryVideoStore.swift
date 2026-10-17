import AVFoundation
import Observation

@MainActor
@Observable
final class SceneryVideoStore {
    private let service = SceneryVideoService()
    private let library: SceneryVideoLibraryService
    private(set) var isLoading = false
    private(set) var isReady = false
    private(set) var registeredVideos: [RegisteredSceneryVideo] = []
    private(set) var registeredVideo: RegisteredSceneryVideo?
    private(set) var errorMessage: String?
    private var request = UUID()
    var player: AVPlayer { service.player }

    init(library: SceneryVideoLibraryService = SceneryVideoLibraryService()) {
        self.library = library
        service.onFailure = { [weak self] message in
            self?.errorMessage = message
            self?.isReady = false
        }
    }

    /// Passing a URL registers a copy; nil restores the previous registration.
    func open(_ source: URL? = nil, preparesPlayback: Bool = true) async {
        let id = UUID()
        request = id
        isLoading = true
        isReady = false
        service.stop()
        errorMessage = nil
        do {
            registeredVideos = try await library.videos()
            if let source {
                do { registeredVideo = try await library.register(source) }
                catch {
                    if error is CancellationError { throw error }
                    // A failed replacement preserves and resumes the previous registration.
                    errorMessage = "動画を登録できませんでした。\(error.localizedDescription)"
                    registeredVideo = try await library.current()
                }
            } else {
                registeredVideo = try await library.current()
            }
            registeredVideos = try await library.videos()
            try Task.checkCancellation()
            guard request == id else { return }
            if preparesPlayback, let registeredVideo {
                let url = await library.url(for: registeredVideo)
                try await service.load(url)
                guard request == id else { return }
                isReady = true
            }
        } catch {
            guard request == id else { return }
            service.stop()
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
        guard request == id else { return }
        isLoading = false
    }

    func select(_ video: RegisteredSceneryVideo) async {
        await updateRegistration(video, removes: false)
    }

    func remove(_ video: RegisteredSceneryVideo) async {
        await updateRegistration(video, removes: true)
    }

    private func updateRegistration(_ video: RegisteredSceneryVideo, removes: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            if removes { try await library.remove(video) }
            else { try await library.select(video) }
            registeredVideos = try await library.videos()
            registeredVideo = try await library.current()
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    func unregister() async {
        guard !isLoading else { return }
        let id = UUID()
        request = id
        service.stop()
        isReady = false
        isLoading = true
        errorMessage = nil
        do {
            try await library.unregister()
            registeredVideo = nil
            registeredVideos = []
        } catch {
            errorMessage = "登録解除に失敗しました。\(error.localizedDescription)"
            registeredVideo = try? await library.current()
        }
        guard request == id else { return }
        isLoading = false
    }

    func setActive(_ active: Bool) { service.setActive(active && isReady && !isLoading) }
    func stop() {
        request = UUID()
        service.stop()
        isReady = false
        isLoading = false
    }
}
