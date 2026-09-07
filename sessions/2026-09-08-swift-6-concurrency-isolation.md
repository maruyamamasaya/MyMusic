# Swift 6 concurrency isolation局所修正

## 作業

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 下で暗黙にMainActor化されていた、Library Favorite、Playback History、Track、Audio Formatの値型を`nonisolated`として明示した。
- Metadata／Music Library Service本体はMainActorから分離し、Track Identity singletonの取得だけをMainActor側のconvenience initializerへ限定した。
- Track Preference PersistenceとTrack Identity actorのdefault argumentを引数なしinitializerへ分離し、Storeのdefault dependency生成もMainActor initializer本文へ移した。
- `TrackSearchWorker`のactor initializerからSwift 6で無効な`nonisolated`を除いた。
- `WorkLibraryCatalogService.build(from:)`を純粋なnonisolated構築関数として明示した。
- AccentColor colorsetから誤ったJPEG参照を除いた。

## 検証

- Generic iOS Simulator Debug build: 成功。
- iPhone 17 Simulator向けtest target build: 成功。
- 指定されていたSwift 6 future-error警告: 0件。
- Unit Test: 171件実行、161件成功、10件失敗。失敗は既存の非同期integration test（Library Genre Filter 1件、Mood Station 9件）で、今回変更した永続化／SQLite／Track Preference／Track Fingerprint／Track Search／Watchの各testは成功した。
- project全targetをSwift 6へ一時的に切り替えた検証では、指定診断解消後にXcode付属Swift 6.3.3が`EqualizerSettingsView.swift`のIR生成でクラッシュしたため、language modeの恒久変更は行っていない。

## 変更しなかったもの

- SQLite schema、migration、JSON／plist形式、保存先、Stable Track Identity、再生、scan、UI、Watch通信仕様は変更していない。
- AppIntents未使用時のmetadata extraction警告と、対象外のWatch runtimeログは未修正。
