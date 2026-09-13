import SwiftUI

struct WatchShuffleView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(WatchShuffleKind.allCases, id: \.self) { kind in
                    Button(title(for: kind)) { sessionManager.shuffle(kind) }
                        .disabled(sessionManager.pendingShuffle != nil)
                }
            } header: {
                Label("シャッフル", systemImage: "shuffle")
            }
            if let kind = sessionManager.pendingShuffle {
                Text("\(title(for: kind))をシャッフル中…")
                    .font(.footnote)
            }
            if let error = sessionManager.shuffleError {
                Text(error).font(.footnote)
            } else if !sessionManager.isPhoneReachable {
                Text("iPhoneに接続できません").font(.footnote)
            }
        }
        .onChange(of: sessionManager.completedShuffleCount) { _, _ in dismiss() }
    }

    private func title(for kind: WatchShuffleKind) -> String {
        switch kind {
        case .normal: "通常"
        case .favorites: "お気に入り"
        case .unplayed: "未発見再生"
        }
    }
}
