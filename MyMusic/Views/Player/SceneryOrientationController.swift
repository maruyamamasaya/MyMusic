import SwiftUI
import UIKit

/// Limits the iPhone orientation only for the lifetime of the scenery presentation.
struct SceneryOrientationHost: UIViewControllerRepresentable {
    var onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> SceneryOrientationController {
        let controller = SceneryOrientationController()
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: SceneryOrientationController, context: Context) {
        uiViewController.onFailure = onFailure
    }

    static func dismantleUIViewController(_ uiViewController: SceneryOrientationController, coordinator: ()) {
        uiViewController.restorePortrait()
    }
}

final class SceneryOrientationController: UIViewController {
    static private(set) var allowedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
    private weak var sceneryScene: UIWindowScene?
    private var hasRequestedLandscape = false
    var onFailure: ((String) -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard UIDevice.current.userInterfaceIdiom == .phone,
              !hasRequestedLandscape, let scene = view.window?.windowScene else { return }
        hasRequestedLandscape = true
        sceneryScene = scene
        Self.allowedOrientations = .landscape
        request(.landscape, in: scene, reportFailure: true)
    }

    func restorePortrait() {
        guard hasRequestedLandscape else { return }
        hasRequestedLandscape = false
        // Restore the app's existing rotation policy, then ask the active scene to return upright.
        Self.allowedOrientations = .allButUpsideDown
        guard let sceneryScene else { return }
        request(.portrait, in: sceneryScene, reportFailure: false)
    }

    private func request(_ orientations: UIInterfaceOrientationMask, in scene: UIWindowScene,
                         reportFailure: Bool) {
        var controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        while let current = controller {
            current.setNeedsUpdateOfSupportedInterfaceOrientations()
            controller = current.presentedViewController
        }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if reportFailure && self.hasRequestedLandscape {
                    self.onFailure?("横向きに切り替えられませんでした。iPhoneを横にしてください。")
                }
                NSLog("Scenery orientation request failed: %@", error.localizedDescription)
            }
        }
    }
}
