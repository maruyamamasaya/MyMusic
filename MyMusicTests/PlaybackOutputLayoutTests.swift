import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import MyMusic

@MainActor
final class PlaybackOutputLayoutTests: XCTestCase {
    func testLongDeviceNameInNowPlayingScreen() async throws {
        let suite = "PlaybackOutputLayoutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let audio = AudioPlayerService()
        let history = PlaybackHistoryStore()
        let player = PlayerStore(audioPlayer: audio, playbackHistoryStore: history, audioInformationService: nil)
        audio.eventHandler?(.outputChanged(
            name: "SUSUMUYAのワイヤレスヘッドホン WH-1000XM5 - Living Room Speaker",
            sampleRate: 48_000,
            portType: AVAudioSession.Port.bluetoothA2DP.rawValue
        ))
        for large in [false, true] {
            let view = NowPlayingView()
                .environment(player)
                .environment(history)
                .environment(SettingsStore(defaults: defaults))
                .environment(LibraryStore(userDefaults: defaults))
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, large ? .accessibility2 : .large)
            let controller = UIHostingController(rootView: view)
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(800))
            controller.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                XCTAssertTrue(controller.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("output-layout-\(large ? "large" : "standard").png")
            try XCTUnwrap(image.pngData()).write(to: url)
            print("OUTPUT_LAYOUT \(url.path)")
            let attachment = XCTAttachment(image: image)
            attachment.name = "Now Playing long output - \(large ? "accessibility" : "standard")"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
            previous?.makeKeyAndVisible()
        }
    }
}
