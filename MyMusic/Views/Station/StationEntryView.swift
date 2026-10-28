import SwiftUI

/// Shared by Home and the regular playlist list.
struct StationEntryView: View {
    @Environment(\.appTheme) private var appTheme
    @Environment(StationStore.self) private var store
    var refreshSeed: UInt64 = 0
    @State private var backgroundImageName: String?
    @State private var showsQuestions = false
    @State private var backgroundImage: UIImage?

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
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("気分を伝えて再生").font(.title3.bold())
                        Text("2問で、今のあなたに合う音楽を。")
                            .font(.subheadline)
                            .foregroundStyle(foregroundColor.opacity(0.82))
                    }
                    Label("ステーションをつくる", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(backgroundImage == nil ? ThemePalette.resolve(appTheme).accent : foregroundColor)
                }
                .foregroundStyle(foregroundColor)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { stationBackground }
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
        .task(id: refreshSeed) {
            let names = HomeTileBackgroundImage.stationVariantNames
                .filter { $0 != backgroundImageName }.shuffled()
            for name in names {
                if let image = HomeTileBackgroundImage.load(named: name) {
                    backgroundImageName = name
                    backgroundImage = image
                    break
                }
            }
        }
    }

    private var foregroundColor: Color {
        backgroundImage == nil ? .primary : .white
    }

    @ViewBuilder
    private var stationBackground: some View {
        if let backgroundImage {
            GeometryReader { proxy in
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.18), .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            LinearGradient(
                colors: [ThemePalette.resolve(appTheme).accent.opacity(0.14), Color.teal.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
