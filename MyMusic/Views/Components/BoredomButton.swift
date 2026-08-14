import SwiftUI

struct BoredomButton: View {
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(PlayerStore.self) private var playerStore

    let track: Track
    @State private var feedbackTrigger = 0

    private var level: Int { historyStore.boredomLevel(for: track.id) }

    var body: some View {
        Image(systemName: level == 0 ? "hourglass" : "hourglass.bottomhalf.filled")
            .font(.title3)
            .foregroundStyle(color)
            .frame(width: 42, height: 36)
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                Text("\(level)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(color, in: Capsule())
                    .opacity(level == 0 ? 0 : 1)
                    .offset(y: -2)
            }
            .onTapGesture(perform: markTemporarilyBored)
            .onLongPressGesture(minimumDuration: 0.7, perform: markPermanentlyBored)
            .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
            .accessibilityElement()
            .accessibilityLabel("飽きた")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("タップで一時的に、長押しで永久にランダム再生から除外")
            .accessibilityAction(named: "永久に除外") { markPermanentlyBored() }
    }

    private var color: Color {
        switch level {
        case 1: .yellow
        case 2: .orange
        case 3: .red
        default: .secondary
        }
    }

    private var accessibilityValue: String {
        switch level {
        case 1: "飽き度1、1日間除外"
        case 2: "飽き度2、1週間除外"
        case 3: "飽き度3、永久除外"
        default: "飽き度0"
        }
    }

    private func markTemporarilyBored() {
        historyStore.markBored(for: track.id)
        playerStore.refreshShuffleExclusions()
        feedbackTrigger += 1
    }

    private func markPermanentlyBored() {
        historyStore.permanentlyHideFromShuffle(trackID: track.id)
        playerStore.refreshShuffleExclusions()
        feedbackTrigger += 1
    }
}
