import SwiftUI

/// Minute-aligned digits with a separate, second-aligned blinking colon.
struct SceneryClock: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let fontSize: CGFloat

    var body: some View {
        Group {
            if scenePhase == .active {
                TimelineView(.everyMinute) { context in
                    clockText(at: context.date)
                }
            } else {
                clockText(at: Date())
            }
        }
        .font(.custom("DotGothic16-Regular", fixedSize: fontSize))
        .foregroundStyle(SceneryPlayerAppearance.display.opacity(0.75))
        .fixedSize()
    }

    private func clockText(at date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        let parts = formatter.string(from: date).split(separator: ":")
        return HStack(spacing: 0) {
            Text(String(parts.first ?? "--"))
            if scenePhase == .active && !reduceMotion {
                SceneryClockColon()
            } else {
                Text(":")
            }
            Text(String(parts.last ?? "--"))
        }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("現在時刻")
            .accessibilityValue(date.formatted(date: .omitted, time: .shortened))
    }
}

private struct SceneryClockColon: View {
    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)), by: 1)) { context in
            Text(":")
                .opacity(Int(context.date.timeIntervalSince1970.rounded(.down)) % 2 == 0 ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}
