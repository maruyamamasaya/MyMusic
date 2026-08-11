import Foundation
import MediaPlayer

struct RemoteCommandActions {
    let play: @MainActor () -> Void
    let pause: @MainActor () -> Void
    let togglePlayPause: @MainActor () -> Void
    let next: @MainActor () -> Void
    let previous: @MainActor () -> Void
    let seek: @MainActor (TimeInterval) -> Void
}

@MainActor
protocol RemoteCommandServicing: AnyObject {
    func configure(actions: RemoteCommandActions)
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool)
}

@MainActor
final class RemoteCommandService: RemoteCommandServicing {
    private let commandCenter: MPRemoteCommandCenter
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var isConfigured = false

    init(commandCenter: MPRemoteCommandCenter = .shared()) {
        self.commandCenter = commandCenter
    }

    isolated deinit {
        commandTargets.forEach { command, target in command.removeTarget(target) }
    }

    func configure(actions: RemoteCommandActions) {
        guard !isConfigured else { return }
        isConfigured = true

        register(commandCenter.playCommand) { _ in perform(actions.play) }
        register(commandCenter.pauseCommand) { _ in perform(actions.pause) }
        register(commandCenter.togglePlayPauseCommand) { _ in perform(actions.togglePlayPause) }
        register(commandCenter.nextTrackCommand) { _ in perform(actions.next) }
        register(commandCenter.previousTrackCommand) { _ in perform(actions.previous) }
        register(commandCenter.changePlaybackPositionCommand) { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return perform { actions.seek(event.positionTime) }
        }
    }

    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {
        commandCenter.playCommand.isEnabled = hasTrack
        commandCenter.pauseCommand.isEnabled = hasTrack
        commandCenter.togglePlayPauseCommand.isEnabled = hasTrack
        commandCenter.changePlaybackPositionCommand.isEnabled = hasTrack
        commandCenter.nextTrackCommand.isEnabled = canGoNext
        commandCenter.previousTrackCommand.isEnabled = canGoPrevious
    }

    private func register(_ command: MPRemoteCommand, handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        let target = command.addTarget(handler: handler)
        commandTargets.append((command, target))
    }
}

private func perform(_ action: @escaping @MainActor () -> Void) -> MPRemoteCommandHandlerStatus {
    Task { @MainActor in action() }
    return .success
}
