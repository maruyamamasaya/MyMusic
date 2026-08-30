import SwiftUI

struct StationQuestionView: View {
    @Environment(StationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("音楽ライブラリを準備中…")
                } else if store.phase == .generating {
                    ProgressView("今の気分に合う曲を選んでいます…")
                } else if store.phase == .result {
                    StationResultView(onPlay: { dismiss() })
                } else if store.availableFeatureCount == 0 {
                    unavailable
                } else {
                    questions
                }
            }
            .navigationTitle("気分を伝えて再生")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if store.phase == .sound || store.phase == .refinement || store.phase == .decade || store.phase == .result {
                    ToolbarItem(placement: .primaryAction) {
                        Button("回答を戻る") { store.goBack() }
                    }
                }
            }
        }
        .task { await store.prepare() }
        .task(id: store.phase) {
            if store.phase == .generating { await store.generate() }
        }
    }

    private var unavailable: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView(
                    store.hasLibraryTracks ? "選曲に使える特徴量がありません" : "まず音楽を追加しましょう",
                    systemImage: "waveform.path",
                    description: Text(store.hasLibraryTracks
                        ? "通常再生の対象曲に特徴量を登録すると、気分からステーションを作れます。作業用の曲やシャッフルから除外した曲は対象外です。"
                        : "ライブラリに音楽を追加し、その曲の特徴量JSONを読み込んでください。")
                )
                if let error = store.featureLoadError {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
                NavigationLink("音楽特徴量の設定を開く") { TrackFeatureSettingsView() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private var questions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(stepLabel).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                    Text(questionTitle).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(questionDetail).font(.subheadline).foregroundStyle(.secondary)
                }
                if let error = store.errorMessage {
                    Label(error, systemImage: "info.circle")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    switch store.phase {
                    case .mood:
                        ForEach(StationMood.allCases) { mood in
                            StationAnswerButton(title: mood.title, symbol: mood.symbol, selected: store.mood == mood) {
                                store.chooseMood(mood)
                            }
                        }
                    case .sound:
                        ForEach(StationSound.allCases) { sound in
                            StationAnswerButton(title: sound.title, symbol: sound.symbol, selected: store.sound == sound) {
                                store.chooseSound(sound)
                            }
                        }
                    case .refinement:
                        if let refinement = store.refinement {
                            StationAnswerButton(title: refinement.firstTitle, symbol: "circle.lefthalf.filled",
                                                selected: store.direction == .first) { store.chooseDirection(.first) }
                            StationAnswerButton(title: refinement.secondTitle, symbol: "circle.righthalf.filled",
                                                selected: store.direction == .second) { store.chooseDirection(.second) }
                            Button("どちらでも・このままつくる") { store.chooseDirection(nil) }
                                .font(.subheadline).padding(.vertical, 12)
                        }
                    case .decade:
                        StationAnswerButton(
                            title: "すべての年代", symbol: "calendar", selected: store.decade == nil
                        ) { store.chooseDecade(nil) }
                        ForEach(store.availableDecades) { decade in
                            StationAnswerButton(
                                title: decade.title,
                                symbol: "calendar.badge.clock",
                                selected: store.decade == decade
                            ) { store.chooseDecade(decade) }
                        }
                    case .generating, .result: EmptyView()
                    }
                }
                Text("特徴量のある\(store.availableFeatureCount)曲から選曲。質問に答えても、再生中の音楽は止まりません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .defaultScrollAnchor(.top)
        .id(store.phase)
    }

    private var stepLabel: String {
        switch store.phase {
        case .mood: "QUESTION 1"
        case .sound: "QUESTION 2"
        case .decade: "最後に、年代を選ぶ"
        default: "最後に、もうひとつ"
        }
    }

    private var questionTitle: String {
        switch store.phase {
        case .mood: "今、どんな音楽がほしい？"
        case .sound: "今日はどんな音の感じがいい？"
        case .decade: "どの年代から聴きたい？"
        default: "最後に、今日はどっち寄り？"
        }
    }

    private var questionDetail: String {
        switch store.phase {
        case .mood: "今の気分に近いものを、ひとつ。"
        case .sound: "\(store.mood?.title ?? "")気分に、どんな音を合わせましょう。"
        case .decade: "曲の年メタデータを使って絞り込みます。迷ったら、すべての年代のままで大丈夫です。"
        default: store.refinement?.explanation ?? ""
        }
    }
}

struct StationAnswerButton: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title).font(.body.weight(.medium)).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Color.primary.opacity(selected ? 0.1 : 0.045), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
