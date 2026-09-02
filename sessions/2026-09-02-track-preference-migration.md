# Track Preference Migration

## 作業

- 曲Favoriteと`playbackPreference`の正本を`TrackPreferenceStore`へ分離した。
- `track-preferences.json` schema v2を追加し、未作成時だけ旧Playback History値をatomic保存・再読込検証して移行する。
- History読込失敗時は空Preferenceを確定しない。旧History fieldとSQLite列はmigration／decode互換用に残す。
- Favorite／評価UI、Favorites画面、検索、選曲、分析、データ管理ExportをPreference参照へ切り替えた。
- Preference Exportを`trackId`、`playbackPreference`、`favorite`を持つschema v2にした。Library／HistoryのFavoriteは互換fieldとしてPreference値をミラーする。
- AnalyticsはPreference schema v1/v2を受理し、v2 FavoriteをLibraryの旧値より優先する。

## 検証

- Preference migration、再読込、Favorite／評価の同一正本保存、schema v2 ExportのXCTestを追加した。
- Analytics Python unittest 14件、Python compileall、JavaScript構文確認が成功した。`git diff --check`もエラーなし（改行コードwarningのみ）。

## 未検証

- Windows環境のためXcode build／Simulator XCTest／実機migrationは未実施。
