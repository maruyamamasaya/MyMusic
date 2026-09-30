import SwiftUI

@main
struct MyMusicWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            NowPlayingView()
                .environment(sessionManager)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { sessionManager.refreshConnectionAndState() }
                }
        }
    }
}
