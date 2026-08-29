import Foundation
import Observation

struct LibraryFolder: Identifiable, Hashable {
    let url: URL
    var id: String { url.standardizedFileURL.path }
    var name: String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\(parent) / \(url.lastPathComponent)"
    }
}

@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var genres: [Genre] = []
    private(set) var composers: [Composer] = []
    private(set) var libraryFolders: [LibraryFolder] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isInitialLoadComplete = false
    private(set) var genreDisplayPresets: [GenreDisplayPreset]

    var availableGenreOptions: [GenreDisplayOption] {
        var options = allGenres.map { GenreDisplayOption(id: $0.name, name: $0.name) }
        if allTracks.contains(where: { Self.genreNames(in: $0.genre).isEmpty }) {
            options.append(GenreDisplayOption(id: Self.unassignedGenreKey, name: "ジャンル未設定"))
        }
        return options
    }

    var unfilteredTracks: [Track] { allTracks }

    var hasLibraryFolder: Bool { !libraryFolders.isEmpty }
    var scanProgress: Int { tracks.count }

    private var librariesByFolderID: [String: MusicLibrary] = [:]
    private var allTracks: [Track] = []
    private var allGenres: [Genre] = []
    private var disabledGenreNames: Set<String>
    private var hasRestoredFolder = false
    private let service: MusicLibraryServicing
    private let fileImportService: FileImportServicing
    private let persistence: LibraryPersistenceServicing
    private let identityService: TrackIdentityServicing
    private let userDefaults: UserDefaults
    private static let disabledGenresKey = "library.disabledGenreNames"
    private static let genrePresetsKey = "library.genreDisplayPresets"
    private static let unassignedGenreKey = "maruyama.MyMusic.genre.unassigned"

    init(service: MusicLibraryServicing? = nil, fileImportService: FileImportServicing? = nil,
         persistence: LibraryPersistenceServicing? = nil, identityService: TrackIdentityServicing? = nil,
         userDefaults: UserDefaults = .standard) {
        let importer = fileImportService ?? FileImportService()
        let identities = identityService ?? TrackIdentityService.shared
        self.fileImportService = importer
        self.identityService = identities
        self.service = service ?? MusicLibraryService(fileImportService: importer,
            metadataService: MetadataService(identityService: identities), identityService: identities)
        self.persistence = persistence ?? LibraryPersistenceService()
        self.userDefaults = userDefaults
        self.disabledGenreNames = Set(userDefaults.stringArray(forKey: Self.disabledGenresKey) ?? [])
        self.genreDisplayPresets = userDefaults.data(forKey: Self.genrePresetsKey)
            .flatMap { try? JSONDecoder().decode([GenreDisplayPreset].self, from: $0) } ?? []
    }

    func restoreAndLoadIfNeeded() async {
        guard !hasRestoredFolder else { return }
        hasRestoredFolder = true
        defer { isInitialLoadComplete = true }
        do {
            libraryFolders = normalized(try fileImportService.restoreLibraryFolders()).map(LibraryFolder.init)
            for folder in libraryFolders {
                if let cached = try? await persistence.load(for: folder.url) {
                    librariesByFolderID[folder.id] = cached
                    Task { [identityService] in await identityService.registerExistingTracks(cached.tracks, in: folder.url) }
                } else {
                    await scan(folder)
                }
            }
            rebuildCombinedLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFolders(_ urls: [URL]) async {
        errorMessage = nil
        let oldIDs = Set(libraryFolders.map(\.id))
        let normalizedURLs = normalized(libraryFolders.map(\.url) + urls)
        let newFolders = normalizedURLs.map(LibraryFolder.init)
        do {
            try fileImportService.saveLibraryFolders(normalizedURLs)
            libraryFolders = newFolders
            librariesByFolderID = librariesByFolderID.filter { newFolders.map(\.id).contains($0.key) }
            for folder in newFolders where !oldIDs.contains(folder.id) { await scan(folder) }
            rebuildCombinedLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func removeFolder(_ folder: LibraryFolder) async {
        let remaining = libraryFolders.filter { $0.id != folder.id }
        do {
            try fileImportService.saveLibraryFolders(remaining.map(\.url))
            libraryFolders = remaining
            librariesByFolderID.removeValue(forKey: folder.id)
            errorMessage = nil
            rebuildCombinedLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func rescan() async {
        guard !libraryFolders.isEmpty else { errorMessage = "先に音楽フォルダを選択してください。"; return }
        for folder in libraryFolders { await scan(folder) }
        rebuildCombinedLibrary()
    }

    func dismissError() { errorMessage = nil }
    func isGenreEnabled(_ genreName: String) -> Bool { !disabledGenreNames.contains(genreName) }
    func setGenre(_ genreName: String, isEnabled: Bool) {
        if isEnabled {
            disabledGenreNames.remove(genreName)
        } else {
            disabledGenreNames.insert(genreName)
        }
        saveDisabledGenres()
        applyGenreFilter()
    }
    func setEnabledGenres(_ genreNames: Set<String>) {
        disabledGenreNames = Set(availableGenreOptions.map(\.id)).subtracting(genreNames)
        saveDisabledGenres()
        applyGenreFilter()
    }
    func showAllGenres() {
        setEnabledGenres(Set(availableGenreOptions.map(\.id)))
    }
    var areAllGenresEnabled: Bool {
        availableGenreOptions.allSatisfy { isGenreEnabled($0.id) }
    }
    func saveGenreDisplayPreset(named name: String) {
        let enabledGenreNames = Set(availableGenreOptions.map(\.id).filter(isGenreEnabled))
        saveGenreDisplayPreset(named: name, enabledGenreNames: enabledGenreNames)
    }
    func saveGenreDisplayPreset(named name: String, enabledGenreNames: Set<String>) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if let index = genreDisplayPresets.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            genreDisplayPresets[index].name = trimmedName
            genreDisplayPresets[index].enabledGenreNames = enabledGenreNames
            genreDisplayPresets[index].includesUnassignedGenreSetting = true
        } else {
            genreDisplayPresets.append(GenreDisplayPreset(
                id: UUID(), name: trimmedName, enabledGenreNames: enabledGenreNames,
                includesUnassignedGenreSetting: true
            ))
        }
        saveGenreDisplayPresets()
    }
    func applyGenreDisplayPreset(_ preset: GenreDisplayPreset) {
        disabledGenreNames = Set(availableGenreOptions.map(\.id)).subtracting(enabledGenreKeys(for: preset))
        saveDisabledGenres()
        applyGenreFilter()
    }
    func updateGenreDisplayPreset(_ preset: GenreDisplayPreset, name: String, enabledGenreNames: Set<String>) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = genreDisplayPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        genreDisplayPresets[index].name = trimmedName
        genreDisplayPresets[index].enabledGenreNames = enabledGenreNames
        genreDisplayPresets[index].includesUnassignedGenreSetting = true
        saveGenreDisplayPresets()
    }
    func moveGenreDisplayPresets(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty,
              offsets.allSatisfy(genreDisplayPresets.indices.contains),
              genreDisplayPresets.indices.contains(destination) || destination == genreDisplayPresets.endIndex else { return }

        let movingPresets = offsets.map { genreDisplayPresets[$0] }
        let removedBeforeDestination = offsets.count { $0 < destination }
        for index in offsets.reversed() {
            genreDisplayPresets.remove(at: index)
        }
        genreDisplayPresets.insert(
            contentsOf: movingPresets,
            at: destination - removedBeforeDestination
        )
        saveGenreDisplayPresets()
    }
    func deleteGenreDisplayPreset(_ preset: GenreDisplayPreset) {
        genreDisplayPresets.removeAll { $0.id == preset.id }
        saveGenreDisplayPresets()
    }
    func isGenreDisplayPresetActive(_ preset: GenreDisplayPreset) -> Bool {
        let availableKeys = Set(availableGenreOptions.map(\.id))
        let currentEnabledKeys = availableKeys.filter(isGenreEnabled)
        let presetEnabledKeys = enabledGenreKeys(for: preset).intersection(availableKeys)
        return currentEnabledKeys == presetEnabledKeys
    }
    func tracks(for album: Album) -> [Track] { resolvedTracks(for: album.trackIDs).sorted(by: Self.albumTrackOrder) }
    func tracks(for artist: Artist) -> [Track] {
        let artistTracks = resolvedTracks(for: artist.trackIDs)
        let albumOrder = Dictionary(uniqueKeysWithValues: artist.albumIDs.enumerated().map { ($0.element, $0.offset) })
        var albumByTrackID: [Track.ID: Album.ID] = [:]
        for album in albums { for id in album.trackIDs where albumByTrackID[id] == nil { albumByTrackID[id] = album.id } }
        return artistTracks.sorted {
            let lhs = albumByTrackID[$0.id].flatMap { albumOrder[$0] } ?? .max
            let rhs = albumByTrackID[$1.id].flatMap { albumOrder[$0] } ?? .max
            return lhs != rhs ? lhs < rhs : Self.albumTrackOrder($0, $1)
        }
    }
    func albums(for artist: Artist) -> [Album] {
        let byID = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        return artist.albumIDs.compactMap { byID[$0] }
    }
    func reportFolderImportFailure(_ error: Error) {
        guard (error as NSError).code != NSUserCancelledError else { return }
        errorMessage = "フォルダを選択できませんでした: \(error.localizedDescription)"
    }

    private func scan(_ folder: LibraryFolder) async {
        isLoading = true; defer { isLoading = false }
        do {
            let previous = librariesByFolderID[folder.id]?.tracks ?? []
            let library = try await service.loadLibrary(from: folder.url, previousTracks: previous)
            // The user may unregister this folder while its asynchronous scan is running.
            // Do not restore scan results for a folder that is no longer registered.
            guard libraryFolders.contains(where: { $0.id == folder.id }) else { return }
            librariesByFolderID[folder.id] = library
            try await persistence.save(library, for: folder.url)
            rebuildCombinedLibrary()
        } catch is CancellationError { return }
        catch {
            // Likewise, a late access error from an unregistered folder should not be
            // presented after the user has successfully removed its registration.
            guard libraryFolders.contains(where: { $0.id == folder.id }) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildCombinedLibrary() {
        var seenPaths: Set<String> = []
        let combined = libraryFolders.flatMap { librariesByFolderID[$0.id]?.tracks ?? [] }.filter {
            seenPaths.insert($0.fileURL.resolvingSymlinksInPath().standardizedFileURL.path).inserted
        }
        let completeLibrary = MusicLibrary.build(from: combined)
        allTracks = completeLibrary.tracks
        allGenres = completeLibrary.genres
        applyGenreFilter()
    }
    private func applyGenreFilter() {
        let visibleTracks = allTracks.filter { track in
            let genreNames = Self.genreNames(in: track.genre)
            let filterKeys = genreNames.isEmpty ? Set([Self.unassignedGenreKey]) : genreNames
            return disabledGenreNames.isDisjoint(with: filterKeys)
        }
        apply(MusicLibrary.build(from: visibleTracks))
    }
    private func saveDisabledGenres() {
        userDefaults.set(disabledGenreNames.sorted(), forKey: Self.disabledGenresKey)
    }
    private func saveGenreDisplayPresets() {
        guard let data = try? JSONEncoder().encode(genreDisplayPresets) else { return }
        userDefaults.set(data, forKey: Self.genrePresetsKey)
    }
    private func enabledGenreKeys(for preset: GenreDisplayPreset) -> Set<String> {
        guard preset.includesUnassignedGenreSetting == true else {
            return preset.enabledGenreNames.union([Self.unassignedGenreKey])
        }
        return preset.enabledGenreNames
    }
    private func apply(_ library: MusicLibrary) {
        tracks = library.tracks; albums = library.albums; artists = library.artists
        genres = library.genres; composers = library.composers
    }
    private func resolvedTracks(for ids: [Track.ID]) -> [Track] {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) }); var seen: Set<Track.ID> = []
        return ids.compactMap { seen.insert($0).inserted ? byID[$0] : nil }
    }
    private func normalized(_ urls: [URL]) -> [URL] {
        let unique = Dictionary(urls.map { ($0.resolvingSymlinksInPath().standardizedFileURL.path, $0) }, uniquingKeysWith: { first, _ in first })
        return unique.sorted { $0.key.count < $1.key.count }.reduce(into: [URL]()) { result, item in
            let candidate = item.value.resolvingSymlinksInPath().standardizedFileURL
            guard !result.contains(where: { candidate.pathComponents.starts(with: $0.pathComponents) }) else { return }
            result.append(candidate)
        }
    }
    private static func albumTrackOrder(_ lhs: Track, _ rhs: Track) -> Bool {
        if (lhs.discNumber ?? 1) != (rhs.discNumber ?? 1) { return (lhs.discNumber ?? 1) < (rhs.discNumber ?? 1) }
        if let l = lhs.trackNumber, let r = rhs.trackNumber, l != r { return l < r }
        if lhs.trackNumber != nil && rhs.trackNumber == nil { return true }
        if lhs.trackNumber == nil && rhs.trackNumber != nil { return false }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
    private static func genreNames(in value: String?) -> Set<String> {
        guard let value else { return [] }
        return Set(value
            .split(whereSeparator: { $0 == ";" || $0 == "\0" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }
}
