import SwiftUI

struct MusicHistoryChangesView: View {
    let snapshot: MusicHistoryDiscoverySnapshot
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Divider()
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("変化と発見")
                    .font(.title2.weight(.bold))
                Text(snapshot.period.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            if !snapshot.risingTracks.isEmpty {
                risingTracksSection
            }

            if !snapshot.risingArtists.isEmpty {
                risingArtistsSection
            }

            if !snapshot.newDiscoveries.isEmpty {
                newDiscoveriesSection
            }

            if !snapshot.dormantTracks.isEmpty {
                dormantTracksSection
            }

            if !snapshot.hasComparisonData || !snapshot.hasInsights {
                growingHistoryMessage
            }
        }
    }

    private var risingTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(
                title: "最近よく聴いています",
                subtitle: "以前より再生が増えた曲"
            )

            horizontalCarousel {
                ForEach(snapshot.risingTracks) { item in
                    if let history = trackHistories[item.track.id] {
                        NavigationLink {
                            TrackMusicHistoryView(summary: history)
                        } label: {
                            MusicHistoryTrackChangeTile(
                                item: item,
                                currentLabel: snapshot.period.currentLabel,
                                previousLabel: snapshot.period.previousLabel,
                                width: 154
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var risingArtistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(
                title: "最近増えたアーティスト",
                subtitle: "聴く機会が増えている音楽"
            )

            horizontalCarousel {
                ForEach(snapshot.risingArtists) { item in
                    MusicHistoryArtistChangeTile(
                        item: item,
                        currentLabel: snapshot.period.currentLabel,
                        previousLabel: snapshot.period.previousLabel,
                        width: 142
                    )
                }
            }
        }
    }

    private var newDiscoveriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(
                title: snapshot.period.newDiscoveryTitle,
                subtitle: "初めて出会い、繰り返し聴いた曲"
            )

            horizontalCarousel {
                ForEach(snapshot.newDiscoveries) { item in
                    if let history = trackHistories[item.track.id] {
                        NavigationLink {
                            TrackMusicHistoryView(summary: history)
                        } label: {
                            MusicHistoryNewDiscoveryTile(item: item, width: 154)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dormantTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(
                title: "久しぶりにどうですか？",
                subtitle: "以前よく聴いていた曲"
            )

            horizontalCarousel {
                ForEach(snapshot.dormantTracks) { item in
                    if let history = trackHistories[item.track.id] {
                        NavigationLink {
                            TrackMusicHistoryView(summary: history)
                        } label: {
                            MusicHistoryDormantTrackTile(item: item, width: 154)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var growingHistoryMessage: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 5) {
                Text("あなたの音楽史は、これから育っていきます。")
                    .font(.headline)
                Text("音楽を聴き続けると、聴き方の変化や、しばらく離れていた曲が少しずつ見つかります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private func horizontalCarousel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 14) {
                content()
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MusicHistoryTrackChangeTile: View {
    let item: MusicHistoryTrackChange
    let currentLabel: String
    let previousLabel: String
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.track.title)
                .font(.headline)
                .lineLimit(2)
            Text(item.track.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            changeCounts(
                currentLabel: currentLabel,
                currentCount: item.currentPlayCount,
                previousLabel: previousLabel,
                previousCount: item.previousPlayCount
            )
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MusicHistoryArtistChangeTile: View {
    let item: MusicHistoryArtistChange
    let currentLabel: String
    let previousLabel: String
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.representativeTrack.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.name)
                .font(.headline)
                .lineLimit(2)
            changeCounts(
                currentLabel: currentLabel,
                currentCount: item.currentPlayCount,
                previousLabel: previousLabel,
                previousCount: item.previousPlayCount
            )
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MusicHistoryNewDiscoveryTile: View {
    let item: MusicHistoryNewDiscovery
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.track.title)
                .font(.headline)
                .lineLimit(2)
            Text(item.track.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("出会ってから \(item.playCount)回")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tint)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MusicHistoryDormantTrackTile: View {
    let item: MusicHistoryDormantTrack
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AlbumArtworkView(artworkIdentifier: item.track.artworkIdentifier)
                .frame(width: width, height: width)
            Text(item.track.title)
                .font(.headline)
                .lineLimit(2)
            Text(item.track.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("最後に聴いたのは\(item.daysSinceLastPlayed)日前")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private func changeCounts(
    currentLabel: String,
    currentCount: Int,
    previousLabel: String,
    previousCount: Int
) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text("\(currentLabel) \(currentCount)回")
            .foregroundStyle(.tint)
        Text("\(previousLabel) \(previousCount)回")
            .foregroundStyle(.secondary)
    }
    .font(.caption.weight(.semibold).monospacedDigit())
}
