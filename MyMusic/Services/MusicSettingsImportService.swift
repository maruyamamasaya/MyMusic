import Foundation

enum MusicSettingsDocumentKind: String, Codable, Sendable {
    case equalizer = "mymusic.equalizer"
    case genreDisplayPresets = "mymusic.genre-display-presets"
}

struct EqualizerTransferDocument: Codable, Sendable {
    let kind: MusicSettingsDocumentKind
    let version: Int
    let equalizer: EqualizerSettings
    let customPresets: [EqualizerPreset]
}

struct GenreDisplayPresetTransferDocument: Codable, Sendable {
    let kind: MusicSettingsDocumentKind
    let version: Int
    let presets: [GenreDisplayPreset]
}

enum MusicSettingsImportPayload: Sendable {
    case equalizer(settings: EqualizerSettings, customPresets: [EqualizerPreset])
    case genreDisplayPresets([GenreDisplayPreset])
}

enum MusicSettingsImportError: LocalizedError {
    case invalidData
    case unsupportedDocument
    case unsupportedVersion(Int)
    case invalidEqualizer
    case invalidPreset(String)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            "設定JSONを解析できませんでした。"
        case .unsupportedDocument:
            "対応していない設定JSONです。"
        case .unsupportedVersion(let version):
            "設定JSONのversion \(version)には対応していません。"
        case .invalidEqualizer:
            "イコライザー設定に不正な値があります。"
        case .invalidPreset(let name):
            "プリセット「\(name)」に不正な値があります。"
        }
    }
}

struct MusicSettingsImportService: Sendable {
    func parse(data: Data) throws -> MusicSettingsImportPayload {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw MusicSettingsImportError.invalidData
        }
        guard let root = object as? [String: Any],
              let rawKind = root["kind"] as? String,
              let kind = MusicSettingsDocumentKind(rawValue: rawKind) else {
            throw MusicSettingsImportError.unsupportedDocument
        }

        switch kind {
        case .equalizer:
            let document = try decode(EqualizerTransferDocument.self, from: data)
            try validateVersion(document.version)
            guard document.kind == .equalizer else {
                throw MusicSettingsImportError.unsupportedDocument
            }
            return .equalizer(
                settings: try normalized(document.equalizer),
                customPresets: try normalizedEqualizerPresets(document.customPresets)
            )

        case .genreDisplayPresets:
            let document = try decode(GenreDisplayPresetTransferDocument.self, from: data)
            try validateVersion(document.version)
            guard document.kind == .genreDisplayPresets else {
                throw MusicSettingsImportError.unsupportedDocument
            }
            return .genreDisplayPresets(try normalizedGenrePresets(document.presets))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw MusicSettingsImportError.invalidData
        }
    }

    private func validateVersion(_ version: Int) throws {
        guard version == 1 else {
            throw MusicSettingsImportError.unsupportedVersion(version)
        }
    }

    private func normalized(_ settings: EqualizerSettings) throws -> EqualizerSettings {
        guard settings.preamp.isFinite,
              settings.bands.allSatisfy({ $0.frequency.isFinite && $0.gain.isFinite }) else {
            throw MusicSettingsImportError.invalidEqualizer
        }
        var settings = settings
        settings.normalize()
        return settings
    }

    private func normalizedEqualizerPresets(_ presets: [EqualizerPreset]) throws -> [EqualizerPreset] {
        var names: Set<String> = []
        var ids: Set<UUID> = []
        return try presets.map { preset in
            let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = name.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            guard !name.isEmpty,
                  names.insert(normalizedName).inserted,
                  ids.insert(preset.id).inserted,
                  preset.preamp.isFinite,
                  (-12 ... 0).contains(preset.preamp),
                  preset.gains.count == EqualizerSettings.frequencies.count,
                  preset.gains.allSatisfy({ $0.isFinite && (-12 ... 12).contains($0) }) else {
                throw MusicSettingsImportError.invalidPreset(name.isEmpty ? "名称なし" : name)
            }
            return EqualizerPreset(
                id: preset.id,
                name: name,
                preamp: preset.preamp,
                gains: preset.gains,
                isBuiltIn: false
            )
        }
    }

    private func normalizedGenrePresets(_ presets: [GenreDisplayPreset]) throws -> [GenreDisplayPreset] {
        var names: Set<String> = []
        var ids: Set<UUID> = []
        return try presets.map { preset in
            let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = name.folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            let genres = Set(preset.enabledGenreNames.compactMap { rawName -> String? in
                let value = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            })
            guard !name.isEmpty,
                  names.insert(normalizedName).inserted,
                  ids.insert(preset.id).inserted,
                  genres.count == preset.enabledGenreNames.count else {
                throw MusicSettingsImportError.invalidPreset(name.isEmpty ? "名称なし" : name)
            }
            return GenreDisplayPreset(
                id: preset.id,
                name: name,
                enabledGenreNames: genres,
                includesUnassignedGenreSetting: preset.includesUnassignedGenreSetting
            )
        }
    }
}
