import SwiftUI

struct PlaybackDurationCalendarView: View {
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var selectedDate = Date()
    @State private var summary: PlaybackDurationSummary?

    var body: some View {
        List {
            Section {
                DatePicker("日付", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            Section {
                if let summary {
                    LabeledContent("月", value: PlaybackDurationSummary.formatted(
                        summary.seconds(for: selectedDate, component: .month)
                    ))
                    LabeledContent("週", value: PlaybackDurationSummary.formatted(
                        summary.seconds(for: selectedDate, component: .weekOfYear)
                    ))
                    LabeledContent("日", value: PlaybackDurationSummary.formatted(
                        summary.seconds(for: selectedDate, component: .day)
                    ))
                } else {
                    ProgressView("再生時間を集計中…")
                }
            } header: {
                Text("選んだ日を含む期間の総再生時間")
            } footer: {
                Text("日時と再生時間が記録された終了済みの再生履歴を、再生開始日で集計します。日付をまたいだ再生も開始日に含めます。古い履歴や再生中の時間は含まれないため、分析の総再生時間と異なる場合があります。週の区切りは端末のカレンダー設定に従います。")
            }
        }
        .themeScreen()
        .navigationTitle("再生時間カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let events = playbackHistoryStore.entries.values.flatMap(\.playbackEvents)
            summary = await Task.detached {
                PlaybackDurationSummary(events: events)
            }.value
        }
    }
}
