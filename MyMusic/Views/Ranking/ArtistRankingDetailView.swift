import SwiftUI

struct ArtistRankingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    let row: ArtistRankingRow
    let division: ArtistRankingDivision
    let metric: ArtistRankingMetric
    @ScaledMetric private var minimumTileWidth = 140

    private var memberTracks: [Track] {
        let ids = Set(row.trackIDs)
        return library.unfilteredTracks.filter { ids.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        AlbumArtworkView(artworkIdentifier: row.artworkIdentifier).frame(width: 76)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.title).font(.title2.bold())
                            Text(division.title).foregroundStyle(.secondary)
                            Text(ArtistRankingFormatting.value(row, metric: metric)).font(.headline)
                        }
                    }
                    Text("総合 \(row.score.formatted(.number.precision(.fractionLength(1)))) / 100点")
                        .font(.title3.bold())
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumTileWidth))], spacing: 12) {
                        points("再生回数", points: row.countPoints, weight: 0.4, detail: "\(row.playCount)回")
                        points("実聴時間", points: row.timePoints, weight: 0.1,
                               detail: ArtistRankingFormatting.duration(row.seconds))
                        points("Good", points: row.goodPoints, weight: 0.3, detail: "評価合計 \(row.good)")
                        points("お気に入り", points: row.favoritePoints, weight: 0.2, detail: "\(row.favorites)曲")
                    }
                    Text("全登録\(row.totalTrackCount)曲・部門内\(row.trackIDs.count)曲\n回数・時間の補正分母：\(row.divisor.formatted(.number.precision(.fractionLength(2))))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(division.title)の曲").font(.headline)
                    let members = memberTracks
                    Button("この部門の曲を再生", systemImage: "play.fill") { play(members, at: 0) }
                        .buttonStyle(.borderedProminent).disabled(members.isEmpty)
                    LazyVStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 12) {
                                AlbumArtworkView(artworkIdentifier: track.artworkIdentifier).frame(width: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title).font(.body).lineLimit(3)
                                    if let album = track.albumTitle {
                                        Text(album).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button { play(members, at: index) } label: {
                                    Image(systemName: "play.fill").frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(track.title)を再生")
                            }.padding(.vertical, 10)
                            Divider()
                        }
                    }
                }.padding(20)
            }
            .themeScreen()
            .navigationTitle("ランキング詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
        }
    }

    private func points(_ title: String, points: Double, weight: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text("＋\((points * weight).formatted(.number.precision(.fractionLength(1))))点")
                .font(.title2.bold()).foregroundStyle(.tint)
            Text("\(points.formatted(.number.precision(.fractionLength(1))))点 × \(Int(weight * 100))％")
                .font(.caption).foregroundStyle(.secondary)
            Text(detail).font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func play(_ tracks: [Track], at index: Int) {
        player.playQueue(tracks, startingAt: index,
                         startContext: PlaybackStartContext(kind: .manual, source: .artist))
    }
}
