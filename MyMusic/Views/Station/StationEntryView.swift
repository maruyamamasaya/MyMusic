import SwiftUI

/// Shared by Home and the regular playlist list.
struct StationEntryView: View {
    @Environment(StationStore.self) private var store
    @State private var showsQuestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.begin()
                showsQuestions = true
            } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.title2)
                        Spacer()
                        Text("BETA").font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.primary.opacity(0.06), in: Capsule())
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("気分を伝えて再生").font(.title3.bold())
                        Text("2〜3問で、今のあなたに合う音楽を。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Label("ステーションをつくる", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Color.accentColor.opacity(0.14), Color.teal.opacity(0.1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .contentShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("station.create")

            if let station = store.station {
                NavigationLink {
                    StationResultView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("今回のステーション", systemImage: "music.note.list")
                            .font(.subheadline.weight(.semibold))
                        Text(station.answers.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showsQuestions) { StationQuestionView() }
    }
}
