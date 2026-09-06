import SwiftUI

@main
struct MyMusicWatchApp: App {
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            NowPlayingView()
                .environment(sessionManager)
        }
    }
}
