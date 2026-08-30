import SwiftUI

struct StationResultView: View {
    @Environment(StationStore.self) private var store
    var onPlay: (() -> Void)?

    var body: some View {
        let tracks = store.stationTracks
        let durationMinutes = Int(tracks.reduce(0) { $0 + $1.duration } / 60)
        List {
            if let station = store.station {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("今の気分のステーション", systemImage: "dot.radiowaves.left.and.right")
                            .font(.title2.bold())
                        Text(station.answers.summary).font(.subheadline).foregroundStyle(.secondary)
                        Text("\(tracks.count)曲 · 約\(durationMinutes)分")
                            .font(.subheadline.weight(.medium))
                        Text(selectionDetail(for: station))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button {
                            if store.play() { onPlay?() }
                        } label: {
                            Label("このステーションを再生", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(tracks.isEmpty || store.isLoading)
                    }
                    .padding(.vertical, 8)
                } footer: {
                    Text("再生すると現在のキューを置き換えます。ステーションはアプリを終了するまでの一時保存です。通常のプレイリストには追加されません。")
                }
                if tracks.isEmpty {
                    ContentUnavailableView("再生できる曲がありません", systemImage: "music.note",
                                           description: Text("ライブラリや特徴量が変更されています。ステーションを作り直してください。"))
                } else {
                    Section("選ばれた曲") {
                        ForEach(tracks) { track in
                            PlayableTrackRowView(track: track) {
                                if store.play(startingWith: track.id) { onPlay?() }
                            }
                            .disabled(store.isLoading)
                        }
                    }
                }
            }
        }
        .navigationTitle("ステーション")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectionDetail(for station: MoodStation) -> String {
        let prefix = station.answers.decade.map {
            "\($0.title)に該当する、年と特徴量のある\(station.analyzedTrackCount)曲"
        } ?? "特徴量のある\(station.analyzedTrackCount)曲"
        return "\(prefix)のうち、近さの基準を満たした\(station.matchingTrackCount)曲から選びました。"
    }
}
