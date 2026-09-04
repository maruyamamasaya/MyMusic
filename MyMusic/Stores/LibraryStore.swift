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
    private(set) var homePresentationRevision = 0
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var genres: [Genre] = []
    private(set) var composers: [Composer] = []
    private(set) var workLibraryCatalog = WorkLibraryCatalog.empty
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
    private let fileImportService: FileImportServicing
    private let persistence: LibraryPersistenceServicing
    private let identityService: TrackIdentityServicing
    private let syncService: LibrarySyncService
    private let genreFilterService = GenreLibraryFilterService()
    private let userDefaults: UserDefaults
    private var genreFilterTask: Task<Void, Never>?
    private var genreFilterRequestID = UUID()
    private static let disabledGenresKey = "library.disabledGenreNames"
    private static let genrePresetsKey = "library.genreDisplayPresets"
    private static let unassignedGenreKey = "maruyama.MyMusic.genre.unassigned"

    init(service: MusicLibraryServicing? = nil, fileImportService: FileImportServicing? = nil,
         persistence: LibraryPersistenceServicing? = nil, identityService: TrackIdentityServicing? = nil,
         userDefaults: UserDefaults = .standard) {
        let importer = fileImportService ?? FileImportService()
        let identities = identityService ?? TrackIdentityService.shared
        let libraryService = service ?? MusicLibraryService(fileImportService: importer,
            metadataService: MetadataService(identityService: identities), identityService: identities)
        let libraryPersistence = persistence ?? LibraryPersistenceService()
        self.fileImportService = importer
        self.identityService = identities
        self.persistence = libraryPersistence
        self.syncService = LibrarySyncService(service: libraryService, persistence: libraryPersistence)
        self.userDefaults = userDefaults
        self.disabledGenreNames = Set(userDefaults.stringArray(forKey: Self.disabledGenresKey) ?? [])
            .subtracting([Track.workPlaybackGenre])
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
                    await identityService.registerExistingTracks(cached.tracks, in: folder.url)
                } else {
                    await scan(folder)
                }
            }
            await rebuildCombinedLibrary()
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
            await rebuildCombinedLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func removeFolder(_ folder: LibraryFolder) async {
        let remaining = libraryFolders.filter { $0.id != folder.id }
        do {
            try fileImportService.saveLibraryFolders(remaining.map(\.url))
            libraryFolders = remaining
            librariesByFolderID.removeValue(forKey: folder.id)
            errorMessage = nil
            await rebuildCombinedLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func rescan() async {
        guard !libraryFolders.isEmpty else { errorMessage = "先に音楽フォルダを選択してください。"; return }
        for folder in libraryFolders { await scan(folder) }
        await rebuildCombinedLibrary()
    }

    func dismissError() { errorMessage = nil }
    func trackFingerprintsForExport() async -> [Track.ID: String] {
        await identityService.fingerprints(for: allTracks.map(\.id))
    }
    func isGenreAlwaysEnabled(_ genreName: String) -> Bool {
        genreName == Track.workPlaybackGenre
    }
    func isGenreEnabled(_ genreName: String) -> Bool {
        isGenreAlwaysEnabled(genreName) || !disabledGenreNames.contains(genreName)
    }
    func setGenre(_ genreName: String, isEnabled: Bool) {
        guard !isGenreAlwaysEnabled(genreName) else { return }
        if isEnabled {
            disabledGenreNames.remove(genreName)
        } else {
            disabledGenreNames.insert(genreName)
        }
        saveDisabledGenres()
        applyGenreFilter()
    }
    func setEnabledGenres(_ genreNames: Set<String>) {
        disabledGenreNames = Set(availableGenreOptions.map(\.id))
            .subtracting(genreNames.union([Track.workPlaybackGenre]))
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
        let enabledGenreNames = enabledGenreNames.union(alwaysEnabledAvailableGenreNames)
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
        disabledGenreNames = Set(availableGenreOptions.map(\.id))
            .subtracting(enabledGenreKeys(for: preset).union(alwaysEnabledAvailableGenreNames))
        saveDisabledGenres()
        applyGenreFilter()
    }
    func updateGenreDisplayPreset(_ preset: GenreDisplayPreset, name: String, enabledGenreNames: Set<String>) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = genreDisplayPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        genreDisplayPresets[index].name = trimmedName
        genreDisplayPresets[index].enabledGenreNames = enabledGenreNames.union(alwaysEnabledAvailableGenreNames)
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
    @discardableResult
    func importGenreDisplayPresets(_ importedPresets: [GenreDisplayPreset]) -> (added: Int, updated: Int) {
        var added = 0
        var updated = 0
        for importedPreset in importedPresets {
            if let index = genreDisplayPresets.firstIndex(where: {
                $0.name.localizedCaseInsensitiveCompare(importedPreset.name) == .orderedSame
            }) {
                genreDisplayPresets[index].name = importedPreset.name
                genreDisplayPresets[index].enabledGenreNames = importedPreset.enabledGenreNames
                genreDisplayPresets[index].includesUnassignedGenreSetting = importedPreset.includesUnassignedGenreSetting
                updated += 1
            } else {
                let occupiedIDs = Set(genreDisplayPresets.map(\.id))
                genreDisplayPresets.append(GenreDisplayPreset(
                    id: occupiedIDs.contains(importedPreset.id) ? UUID() : importedPreset.id,
                    name: importedPreset.name,
                    enabledGenreNames: importedPreset.enabledGenreNames,
                    includesUnassignedGenreSetting: importedPreset.includesUnassignedGenreSetting
                ))
                added += 1
            }
        }
        saveGenreDisplayPresets()
        return (added, updated)
    }
    func isGenreDisplayPresetActive(_ preset: GenreDisplayPreset) -> Bool {
        let availableKeys = Set(availableGenreOptions.map(\.id))
        let currentEnabledKeys = availableKeys.filter(isGenreEnabled)
        let presetEnabledKeys = enabledGenreKeys(for: preset).intersection(availableKeys)
        return currentEnabledKeys == presetEnabledKeys
    }
    func enabledGenreCount(for preset: GenreDisplayPreset) -> Int {
        enabledGenreKeys(for: preset).intersection(availableGenreOptions.map(\.id)).count
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
            let library = try await syncService.scan(folderURL: folder.url, previousTracks: previous)
            // The user may unregister this folder while its asynchronous scan is running.
            // Do not restore scan results for a folder that is no longer registered.
            guard libraryFolders.contains(where: { $0.id == folder.id }) else { return }
            try await syncService.save(library, for: folder.url)
            guard libraryFolders.contains(where: { $0.id == folder.id }) else { return }
            librariesByFolderID[folder.id] = library
            await rebuildCombinedLibrary()
        } catch is CancellationError { return }
        catch {
            // Likewise, a late access error from an unregistered folder should not be
            // presented after the user has successfully removed its registration.
            guard libraryFolders.contains(where: { $0.id == folder.id }) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildCombinedLibrary() async {
        cancelPendingGenreFilter()
        let folderIDs = libraryFolders.map(\.id)
        let libraries = librariesByFolderID
        let completeLibrary = await syncService.combinedLibrary(
            folderIDs: folderIDs,
            librariesByFolderID: libraries
        )
        guard folderIDs == libraryFolders.map(\.id) else { return }
        allTracks = completeLibrary.tracks
        allGenres = completeLibrary.genres
        applyGenreFilter()
    }
    private func applyGenreFilter() {
        genreFilterTask?.cancel()
        let requestID = UUID()
        genreFilterRequestID = requestID
        let tracks = allTracks
        let disabledGenreNames = disabledGenreNames
        let genreFilterService = genreFilterService

        genreFilterTask = Task(priority: .utility) { [weak self] in
            do {
                let snapshot = try await genreFilterService.filteredLibrary(
                    from: tracks,
                    disabledGenreNames: disabledGenreNames,
                    unassignedGenreKey: Self.unassignedGenreKey
                )
                try Task.checkCancellation()
                guard let self, self.genreFilterRequestID == requestID else { return }
                self.apply(snapshot)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }
    private func cancelPendingGenreFilter() {
        genreFilterTask?.cancel()
        genreFilterTask = nil
        genreFilterRequestID = UUID()
    }
    private func saveDisabledGenres() {
        userDefaults.set(disabledGenreNames.sorted(), forKey: Self.disabledGenresKey)
    }
    private func saveGenreDisplayPresets() {
        guard let data = try? JSONEncoder().encode(genreDisplayPresets) else { return }
        userDefaults.set(data, forKey: Self.genrePresetsKey)
    }
    private func enabledGenreKeys(for preset: GenreDisplayPreset) -> Set<String> {
        let alwaysEnabled = alwaysEnabledAvailableGenreNames
        guard preset.includesUnassignedGenreSetting == true else {
            return preset.enabledGenreNames.union([Self.unassignedGenreKey]).union(alwaysEnabled)
        }
        return preset.enabledGenreNames.union(alwaysEnabled)
    }
    private var alwaysEnabledAvailableGenreNames: Set<String> {
        Set(availableGenreOptions.lazy.map(\.id).filter(isGenreAlwaysEnabled))
    }
    private func apply(_ snapshot: LibraryPresentationSnapshot) {
        let library = snapshot.library
        tracks = library.tracks; albums = library.albums; artists = library.artists
        genres = library.genres; composers = library.composers
        workLibraryCatalog = snapshot.workLibraryCatalog
        homePresentationRevision &+= 1
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
