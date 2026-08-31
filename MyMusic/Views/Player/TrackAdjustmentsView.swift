import SwiftUI

struct TrackAdjustmentsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(TrackPlaybackAdjustmentStore.self) private var adjustmentStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(TrackFeatureStore.self) private var featureStore
    @Environment(SettingsStore.self) private var settingsStore

    let track: Track?
    let onShowArtwork: () -> Void

    @State private var validationMessage: String?
    @State private var confirmedBoundary: PlaybackBoundary?
    @State private var confirmationID = UUID()
    @State private var confirmationTrigger = 0

    private enum PlaybackBoundary {
        case start
        case end
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onShowArtwork) {
                    Label("Track Adjustments", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("ダブルタップしてアートワークに戻る")

                if let track {
                    playbackSection(track)
                    Divider()
                    normalizationSection(track)
                } else {
                    ContentUnavailableView("再生中の曲がありません", systemImage: "music.note")
                }

                Button("アートワークに戻る", action: onShowArtwork)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: track?.id) {
            validationMessage = nil
            confirmedBoundary = nil
            guard let track else { return }
            _ = await adjustmentStore.load(for: track.id, duration: resolvedDuration(for: track))
        }
    }

    @ViewBuilder
    private func playbackSection(_ track: Track) -> some View {
        let adjustment = adjustmentStore.adjustment(for: track.id)
        let duration = resolvedDuration(for: track)

        VStack(alignment: .leading, spacing: 10) {
            Text("再生履歴").font(.subheadline.weight(.semibold))
            valueRow(
                "総再生時間",
                formattedDuration(playbackHistoryStore.totalPlaybackDuration(for: track.id))
            )
            valueRow("スキップ回数", "\(playbackHistoryStore.skipCount(for: track.id))回")
            valueRow("スキップ率", formattedRate(playbackHistoryStore.skipRate(for: track.id)))
            valueRow("完走回数", "\(playbackHistoryStore.fullPlaybackCount(for: track.id))回")
            valueRow("完走率", formattedRate(playbackHistoryStore.completionRate(for: track.id)))
            valueRow("連続再生回数", "\(playbackHistoryStore.consecutivePlayCount(for: track.id))回")
            valueRow("リピート再生回数", "\(playbackHistoryStore.repeatPlaybackCount(for: track.id))回")
            valueRow("最終再生日時", formattedDate(playbackHistoryStore.lastPlayedAt(for: track.id)))

            Divider()

            Text("Playback").font(.subheadline.weight(.semibold))
            valueRow("現在位置", formatted(playerStore.currentTime))
            valueRow("前回位置", formatted(adjustment.lastPlaybackPosition))
            valueRow("開始位置", adjustment.customStartPosition.map(formatted) ?? "未設定")
            valueRow("終了位置", adjustment.customEndPosition.map(formatted) ?? "未設定")

            HStack {
                Button("1秒戻る", systemImage: "gobackward") {
                    playerStore.skip(by: -1)
                }
                .disabled(playerStore.currentTime <= 0)
                .accessibilityHint("開始位置または終了位置を設定する前に現在位置を1秒戻します")

                if adjustment.lastPlaybackPosition > 0,
                   adjustment.lastPlaybackPosition < duration {
                    Button("前回位置へ移動") {
                        playerStore.seek(to: adjustment.lastPlaybackPosition)
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            HStack {
                boundarySettingButton(
                    title: "現在位置を開始位置に設定",
                    boundary: .start
                ) {
                    setStart(track, duration: duration)
                }
                Button("リセット") {
                    Task {
                        _ = await adjustmentStore.setCustomStart(
                            trackID: track.id,
                            position: nil,
                            duration: duration
                        )
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            HStack {
                boundarySettingButton(
                    title: "現在位置を終了位置に設定",
                    boundary: .end
                ) {
                    setEnd(track, duration: duration)
                }
                Button("リセット") {
                    Task {
                        _ = await adjustmentStore.setCustomEnd(
                            trackID: track.id,
                            position: nil,
                            duration: duration
                        )
                        playerStore.refreshActiveTrackAdjustment()
                    }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .sensoryFeedback(.success, trigger: confirmationTrigger)
    }

    @ViewBuilder
    private func normalizationSection(_ track: Track) -> some View {
        let values = featureStore.feature(for: track.id)?.values
        let adjustment = adjustmentStore.adjustment(for: track.id)
        let automatic = values?.normalizationGainDB
        let finalGain = VolumeNormalizationGain.finalDecibels(
            automaticGainDB: automatic,
            manualAdjustmentDB: adjustment.manualNormalizationAdjustmentDB,
            truePeakDBTP: values?.truePeakDBTP
        )

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volume Normalize").font(.subheadline.weight(.semibold))
                Spacer()
                Text(settingsStore.volumeNormalizationEnabled ? "ノーマライズ：ON" : "ノーマライズ：OFF")
                    .font(.caption)
                    .foregroundStyle(settingsStore.volumeNormalizationEnabled ? Color.accentColor : .secondary)
            }

            if values?.integratedLUFS == nil,
               values?.truePeakDBTP == nil,
               automatic == nil {
                Label("音量解析データなし", systemImage: "waveform.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                valueRow("解析音量", formattedDecibels(values?.integratedLUFS, suffix: "LUFS"))
                valueRow("True Peak", formattedDecibels(values?.truePeakDBTP, suffix: "dBTP"))
                valueRow("自動補正", signedDecibels(automatic ?? 0))
            }

            valueRow("手動微調整", signedDecibels(adjustment.manualNormalizationAdjustmentDB))
            valueRow("最終補正", signedDecibels(finalGain))

            HStack(spacing: 16) {
                adjustmentButton(systemName: "minus", enabled: adjustment.manualNormalizationAdjustmentDB > -2) {
                    changeManualAdjustment(track, by: -0.5)
                }
                Text(signedDecibels(adjustment.manualNormalizationAdjustmentDB))
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity)
                adjustmentButton(systemName: "plus", enabled: adjustment.manualNormalizationAdjustmentDB < 2) {
                    changeManualAdjustment(track, by: 0.5)
                }
            }

            Button("手動微調整をリセット") {
                Task {
                    await adjustmentStore.setManualNormalizationAdjustment(
                        trackID: track.id,
                        decibels: 0,
                        duration: resolvedDuration(for: track)
                    )
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            Text("音量の変更は次回の曲開始時から適用されます。OFF時も設定値は保持されます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func setStart(_ track: Track, duration: TimeInterval) {
        Task {
            let succeeded = await adjustmentStore.setCustomStart(
                trackID: track.id,
                position: playerStore.currentTime,
                duration: duration
            )
            if succeeded {
                validationMessage = nil
                showConfirmation(for: .start)
            } else {
                clearConfirmation()
                validationMessage = "開始位置は終了位置より前で、曲の範囲内に設定してください。"
            }
        }
    }

    private func setEnd(_ track: Track, duration: TimeInterval) {
        Task {
            let succeeded = await adjustmentStore.setCustomEnd(
                trackID: track.id,
                position: playerStore.currentTime,
                duration: duration
            )
            if succeeded {
                playerStore.refreshActiveTrackAdjustment()
                validationMessage = nil
                showConfirmation(for: .end)
            } else {
                clearConfirmation()
                validationMessage = "終了位置は開始位置より後で、曲の範囲内に設定してください。"
            }
        }
    }

    private func showConfirmation(for boundary: PlaybackBoundary) {
        let newID = UUID()
        confirmationID = newID
        confirmationTrigger += 1
        withAnimation(.spring(response: 0.25, dampingFraction: 0.62)) {
            confirmedBoundary = boundary
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard confirmationID == newID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                confirmedBoundary = nil
            }
        }
    }

    private func clearConfirmation() {
        confirmationID = UUID()
        withAnimation(.easeOut(duration: 0.2)) {
            confirmedBoundary = nil
        }
    }

    private func changeManualAdjustment(_ track: Track, by amount: Double) {
        let current = adjustmentStore.adjustment(for: track.id).manualNormalizationAdjustmentDB
        Task {
            await adjustmentStore.setManualNormalizationAdjustment(
                trackID: track.id,
                decibels: current + amount,
                duration: resolvedDuration(for: track)
            )
        }
    }

    private func adjustmentButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 44, height: 36)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }

    private func boundarySettingButton(
        title: String,
        boundary: PlaybackBoundary,
        action: @escaping () -> Void
    ) -> some View {
        let isConfirmed = confirmedBoundary == boundary

        return Button(action: action) {
            Label(
                isConfirmed ? "設定しました" : title,
                systemImage: isConfirmed ? "checkmark.circle.fill" : "scope"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .tint(isConfirmed ? .green : .accentColor)
        .background(
            isConfirmed ? Color.green.opacity(0.18) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .shadow(color: isConfirmed ? Color.green.opacity(0.75) : .clear, radius: 8)
        .accessibilityLabel(isConfirmed ? "設定しました" : title)
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
    }

    private func resolvedDuration(for track: Track) -> TimeInterval {
        let currentDuration = playerStore.currentTrack?.id == track.id ? playerStore.duration : 0
        return currentDuration > 0 ? currentDuration : track.duration
    }

    private func formatted(_ time: TimeInterval) -> String {
        let seconds = max(Int(time.isFinite ? time : 0), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func formattedDecibels(_ value: Double?, suffix: String) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.1f %@", value, suffix)
    }

    private func formattedDuration(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time.isFinite ? time : 0), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", totalSeconds / 60, seconds)
    }

    private func formattedRate(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func formattedDate(_ value: Date?) -> String {
        guard let value else { return "未再生" }
        return Self.dateFormatter.string(from: value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private func signedDecibels(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
    }
}
