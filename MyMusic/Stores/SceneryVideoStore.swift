import AVFoundation
import Observation

@MainActor
@Observable
final class SceneryVideoStore {
    private let service = SceneryVideoService()
    private let library = SceneryVideoLibraryService()
    private(set) var isLoading = false
    private(set) var isReady = false
    private(set) var registeredVideo: RegisteredSceneryVideo?
    private(set) var errorMessage: String?
    private var request = UUID()
    var player: AVPlayer { service.player }

    init() {
        service.onFailure = { [weak self] message in
            self?.errorMessage = message
            self?.isReady = false
        }
    }

    /// Passing a URL registers a copy; nil restores the previous registration.
    func open(_ source: URL? = nil) async {
        let id = UUID()
        request = id
        isLoading = true
        isReady = false
        service.stop()
        errorMessage = nil
        do {
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
            try Task.checkCancellation()
            guard request == id else { return }
            if let registeredVideo {
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
