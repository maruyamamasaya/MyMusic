import Foundation

nonisolated struct TrackDetailItem: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String
}

nonisolated enum TrackDetailPresentation {
    static func metadataItems(for track: Track) -> [TrackDetailItem] {
        var items: [TrackDetailItem] = []
        append(&items, id: "album", label: "アルバム", value: track.albumTitle)
        if track.albumArtistName != track.artistName {
            append(&items, id: "albumArtist", label: "アルバムアーティスト", value: track.albumArtistName)
        }
        append(&items, id: "composer", label: "作曲者", value: track.composer)
        append(&items, id: "genre", label: "ジャンル", value: track.genre)
        if let year = track.year {
            items.append(.init(id: "year", label: "年", value: year.formatted()))
        }
        if track.discNumber != nil || track.trackNumber != nil {
            let disc = track.discNumber.map(String.init) ?? "—"
            let number = track.trackNumber.map(String.init) ?? "—"
            items.append(.init(id: "position", label: "ディスク／曲番号", value: "\(disc) / \(number)"))
        }
        items.append(.init(id: "duration", label: "長さ", value: duration(track.duration)))
        return items
    }

    static func audioItems(for track: Track) -> [TrackDetailItem] {
        guard let format = track.audioFormat else { return [] }
        var items = [TrackDetailItem(
            id: "quality",
            label: "音源品質",
            value: format.isHiResolution ? "Hi-Res" : (format.isLossless ? "Lossless" : "圧縮音源")
        )]
        items.append(.init(id: "codec", label: "コーデック", value: format.codec.rawValue))
        if let bitRate = format.bitRate {
            items.append(.init(id: "bitRate", label: "ビットレート", value: "\(bitRate / 1_000) kbps"))
        }
        if let sampleRate = format.sampleRate {
            items.append(.init(id: "sampleRate", label: "サンプルレート", value: rate(sampleRate)))
        }
        if let bitDepth = format.bitDepth {
            items.append(.init(id: "bitDepth", label: "ビット深度", value: "\(bitDepth) bit"))
        }
        if let channels = format.channels {
            items.append(.init(id: "channels", label: "チャンネル", value: channelDescription(channels)))
        }
        return items
    }

    static func fileItems(for track: Track) -> [TrackDetailItem] {
        var items = [TrackDetailItem(id: "fileName", label: "ファイル名", value: track.fileURL.lastPathComponent)]
        if let fileSize = track.fileSize {
            items.append(.init(id: "fileSize", label: "ファイル容量", value: FileSizeFormatter.string(from: fileSize)))
        }
        append(&items, id: "relativePath", label: "ライブラリ内パス", value: track.relativePath)
        if let firstSeenAt = track.firstSeenAt {
            items.append(.init(id: "firstSeenAt", label: "ライブラリ登録", value: date(firstSeenAt)))
        }
        if let modificationDate = track.modificationDate {
            items.append(.init(id: "modificationDate", label: "ファイル更新", value: date(modificationDate)))
        }
        return items
    }

    static func featureItems(for feature: TrackFeature) -> [TrackDetailItem] {
        let values = feature.values
        var items: [TrackDetailItem] = []
        if let tempo = values.tempo, tempo.isFinite, tempo > 0 {
            items.append(.init(id: "tempo", label: "Tempo", value: String(format: "%.1f BPM", tempo)))
        }
        if let energy = validScore(values.energy) {
            items.append(.init(id: "energy", label: "Energy", value: percent(energy)))
        }
        for item in TrackFeaturePresentation.categoryItems(for: values).prefix(5) {
            items.append(.init(id: "feature-\(item.id)", label: item.label, value: percent(item.score)))
        }
        if let integratedLUFS = values.integratedLUFS, integratedLUFS.isFinite {
            items.append(.init(id: "lufs", label: "解析音量", value: String(format: "%.1f LUFS", integratedLUFS)))
        }
        if let truePeak = values.truePeakDBTP, truePeak.isFinite {
            items.append(.init(id: "truePeak", label: "True Peak", value: String(format: "%.1f dBTP", truePeak)))
        }
        items.append(.init(id: "analysisVersion", label: "解析バージョン", value: "v\(feature.analysisVersion)"))
        items.append(.init(id: "analyzedAt", label: "解析日時", value: date(feature.analyzedAt)))
        return items
    }

    private static func append(
        _ items: inout [TrackDetailItem],
        id: String,
        label: String,
        value: String?
    ) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        items.append(.init(id: id, label: label, value: value))
    }

    private static func validScore(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    private static func duration(_ value: TimeInterval) -> String {
        let seconds = max(Int(value.isFinite ? value : 0), 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }

    private static func rate(_ value: Double) -> String {
        String(format: "%.1f kHz", value / 1_000)
    }

    private static func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1: "モノラル"
        case 2: "ステレオ"
        default: "\(channels) ch"
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static func date(_ value: Date) -> String {
        value.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: "ja_JP"))
        )
    }
}
