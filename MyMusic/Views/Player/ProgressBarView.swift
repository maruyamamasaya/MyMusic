import SwiftUI

struct ProgressBarView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    @State private var sliderValue: Double
    init(currentTime: TimeInterval, duration: TimeInterval) { self.currentTime = currentTime; self.duration = duration; _sliderValue = State(initialValue: currentTime) }
    var body: some View { VStack { Slider(value: $sliderValue, in: 0...max(duration, 1)); HStack { Text(TimeFormatter.string(from: currentTime)); Spacer(); Text("-" + TimeFormatter.string(from: max(duration - currentTime, 0))) }.font(.caption).foregroundStyle(.secondary).monospacedDigit() } }
}
