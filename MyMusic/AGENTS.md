# iOS アプリケーション規約

最初にルートの [AGENTS.md](../AGENTS.md) を読みます。このディレクトリは SwiftUI iPhone アプリと XCTest suite を所有します。

- `View → Store → Service → Model / Apple Framework` を守ります。AVFoundation と security-scoped file access は `AudioPlayerService` に置き、View に business logic を置きません。
- Swift、SwiftUI、Observation、Apple frameworks を優先します。Model に UI logic を置かず、適切なら `Identifiable` / `Hashable` / `Codable` を採用します。
- iPhone、Light/Dark Mode、Dynamic Type、片手操作を考慮します。SF Symbols を優先し、過度な固定サイズを避けます。
- decode 互換性と非破壊的永続化を維持します。Stable Track ID は playlist、preference、history、feature、Watch state が参照するため、変更時は migration を確認します。
- 編集前に [SOURCE_INDEX.md](../SOURCE_INDEX.md) から definition、references、関連 Store/Service、保存境界、XCTest を検索します。
- 実装中は対象 XCTest、意味のある Swift 変更の完了前は [TESTING.md](../TESTING.md) の Full validation を行います。File System Synchronized Groups を尊重し、不要な `project.pbxproj` 編集を避けます。
