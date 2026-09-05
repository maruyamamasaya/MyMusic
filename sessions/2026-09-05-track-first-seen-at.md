# Track firstSeenAt

## 作業

- Track、library scan、metadata、sync、folder snapshot、Identity全照合、移動・更新、Library／Playlist／Playback／Feature／Settings export/import、Analytics schema/import/query、Analyzer／Semantic reader、関連fixtureとテストを横断確認した。
- Trackとidentity Recordへoptional `firstSeenAt` を追加し、scan共通時刻の注入、既存値継承、削除後再追加のregistry復元、失敗scan rollbackを実装した。
- Library JSON／MarkdownとAnalytics nullable列へ連携した。Library exportはoptional追加のためversion 1を維持した。
- Playlist等の非Library契約とAnalyzer schemaには追加していない。
- Homeの「未発見再生」の直後へ「最近追加した曲」タイルを追加し、`firstSeenAt`が現在から14日以内の通常再生対象曲をPreference＋Overplay weightでシャッフル再生するようにした。追加日時不明・未来・期間外・作業用は除外する。

## 検証

- Analytics unittest: 46 tests passed。
- Analyzer／Semantic unittest（`.venv` Python 3.14.7）: 38 tests passed。system Python 3.10.4では既存コードが必要とする`hashlib.file_digest`がなくSemantic 17件が環境エラーになったため、project環境で再実行した。
- iOS関連XCTest（Track firstSeen、Identity、Library Sync、Data Export、Playlist transfer）: 12 tests passed。
- 最近追加タイル／14日境界の追加XCTestを含むTrack firstSeen＋Home category: 10 tests passed。
- XCTest全体では今回追加3件を含む多数が成功したが、既存の非同期テスト4件（StationStoreIntegrationTests 2件、LibraryGenreFilterTests 1件、TrackPreferencePersistenceTests 1件）が失敗した。今回の関連suiteを分離再実行して成功を確認した。
- iOS Simulator Debug build: `BUILD SUCCEEDED`。既存のSwift 6 actor isolation／AppIntents警告のみ。

## 未解決

- 最近追加と未再生／特徴量の組合せ、Highlight／Discovery補正は未実装。
