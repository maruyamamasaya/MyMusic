import SwiftUI

struct MusicHistoryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var snapshot = MusicHistorySnapshot.empty
    @State private var selectedYear: Int?
    @State private var hasLoadedSnapshot = false

    private var displayedYear: MusicHistorySnapshot.Year? {
        snapshot.years.first { $0.year == selectedYear } ?? snapshot.years.first
    }

    private var dataRevision: MusicHistoryDataRevision {
        MusicHistoryDataRevision(
            historyIsLoaded: playbackHistoryStore.isLoaded,
            libraryIsLoaded: libraryStore.isInitialLoadComplete,
            historyEntryCount: playbackHistoryStore.entries.count,
            playbackEventCount: playbackHistoryStore.entries.values.reduce(0) {
                $0 + $1.playbackEvents.count
            },
            libraryTrackCount: libraryStore.unfilteredTracks.count
        )
    }

    var body: some View {
        Group {
            if !hasLoadedSnapshot {
                ProgressView("音楽史をまとめています…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if snapshot.years.isEmpty {
                ContentUnavailableView(
                    "再生履歴はありません",
                    systemImage: "calendar.badge.clock",
                    description: Text("再生が完了した曲の履歴が保存されると、アートワークと一緒に一年を振り返れます。")
                )
            } else if let displayedYear {
                yearContent(displayedYear)
            }
        }
        .navigationTitle("音楽史")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: dataRevision) { await rebuildSnapshot() }
    }

    private func yearContent(_ year: MusicHistorySnapshot.Year) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                yearHeader(year)

                if let topTrack = year.mostPlayedTrack {
                    if let history = snapshot.memories.trackHistories[topTrack.track.id] {
                        NavigationLink {
                            TrackMusicHistoryView(summary: history)
                        } label: {
                            MusicHistoryHeroView(
                                eyebrow: "この年の1曲",
                                item: topTrack,
                                artworkMaxWidth: 320
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                summarySection(year)
                artistsSection(year)
                tracksSection(year)
                monthsSection(year)

                if year.id == snapshot.years.first?.id,
                   let changesAndDiscovery = snapshot.changesAndDiscovery {
                    MusicHistoryChangesView(
                        snapshot: changesAndDiscovery,
                        trackHistories: snapshot.memories.trackHistories
                    )
                }

                moreHistorySection(year)
            }
            .padding(.vertical, 16)
        }
    }

    private func yearHeader(_ year: MusicHistorySnapshot.Year) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(year.year))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("MY MUSIC YEAR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.4)
            }

            Spacer()

            Picker("年を選ぶ", selection: yearSelection) {
                ForEach(snapshot.years) { year in
                    Text("\(year.year)年").tag(year.year)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 16)
    }

    private func summarySection(_ year: MusicHistorySnapshot.Year) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(title: "一年の記録", subtitle: "\(year.year)年に聴いた音楽")
            MusicHistoryMetricsView(metrics: [
                MusicHistoryMetric(title: "再生", value: year.playCount, unit: "回"),
                MusicHistoryMetric(title: "曲", value: year.trackCount, unit: "曲"),
                MusicHistoryMetric(title: "アーティスト", value: year.artistCount, unit: "組"),
                MusicHistoryMetric(title: "月", value: year.monthCount, unit: "か月")
            ])
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func artistsSection(_ year: MusicHistorySnapshot.Year) -> some View {
        if !year.topArtists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MusicHistorySectionHeader(title: "この年のアーティスト", subtitle: "よく聴いたTOP5")

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(year.topArtists.prefix(5)) { item in
                            MusicHistoryArtistTile(item: item, width: 142)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private func tracksSection(_ year: MusicHistorySnapshot.Year) -> some View {
        if !year.topTracks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MusicHistorySectionHeader(title: "よく聴いた曲", subtitle: "この一年を彩ったTOP10")

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(year.topTracks) { item in
                            if let history = snapshot.memories.trackHistories[item.track.id] {
                                NavigationLink {
                                    TrackMusicHistoryView(summary: history)
                                } label: {
                                    MusicHistoryTrackTile(item: item, width: 154)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func monthsSection(_ year: MusicHistorySnapshot.Year) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(title: "12か月の音楽", subtitle: "各月を代表する1曲")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 150), spacing: 14)],
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(year.months) { month in
                    NavigationLink {
                        MusicHistoryMonthView(
                            month: month,
                            trackHistories: snapshot.memories.trackHistories
                        )
                    } label: {
                        MusicHistoryMonthTile(month: month)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func moreHistorySection(_ year: MusicHistorySnapshot.Year) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MusicHistorySectionHeader(
                title: "もっと振り返る",
                subtitle: "日々と曲に残った音楽の記憶"
            )

            VStack(spacing: 12) {
                NavigationLink {
                    MusicHistoryCalendarView(
                        years: snapshot.memories.calendarYears,
                        trackHistories: snapshot.memories.trackHistories,
                        initialYear: year.year
                    )
                } label: {
                    MusicHistoryDestinationRow(
                        title: "音楽カレンダー",
                        subtitle: "音楽を聴いていた日々を眺める",
                        systemImage: "calendar"
                    )
                }

                NavigationLink {
                    MusicHistoryTimeCapsuleView(
                        capsules: snapshot.memories.timeCapsules,
                        trackHistories: snapshot.memories.trackHistories
                    )
                } label: {
                    MusicHistoryDestinationRow(
                        title: "タイムカプセル",
                        subtitle: "過去の同じ時期に聴いた音楽",
                        systemImage: "archivebox"
                    )
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private var yearSelection: Binding<Int> {
        Binding(
            get: {
                selectedYear
                    ?? snapshot.availableYears.first
                    ?? Calendar.current.component(.year, from: Date())
            },
            set: { selectedYear = $0 }
        )
    }

    @MainActor
    private func rebuildSnapshot() async {
        guard playbackHistoryStore.isLoaded, libraryStore.isInitialLoadComplete else { return }

        let analytics = AnalyticsService().makeSnapshot(
            tracks: libraryStore.unfilteredTracks,
            historyEntries: playbackHistoryStore.entries,
            playlists: []
        )
        snapshot = MusicHistoryService().makeSnapshot(
            playbackMonths: analytics.playbackMonths,
            historyEntries: playbackHistoryStore.entries,
            now: Date()
        )
        normalizeSelectedYear()
        hasLoadedSnapshot = true
    }

    private func normalizeSelectedYear() {
        guard !snapshot.availableYears.isEmpty else {
            selectedYear = nil
            return
        }
        if selectedYear.map(snapshot.availableYears.contains) != true {
            selectedYear = snapshot.availableYears.first
        }
    }
}

private struct MusicHistoryDataRevision: Hashable {
    let historyIsLoaded: Bool
    let libraryIsLoaded: Bool
    let historyEntryCount: Int
    let playbackEventCount: Int
    let libraryTrackCount: Int
}

private struct MusicHistoryDestinationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}
