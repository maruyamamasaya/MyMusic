# App外バックアップ v1

通常運用の正本は `Application Support/MyMusic` のままにし、ユーザーがFilesまたはiCloud Driveで選んだフォルダの `MyMusic Backup/latest` と `previous` に最大2世代を保存する。音源は複製しない。

## 対象の棚卸し

| 分類 | データ | 理由 |
| --- | --- | --- |
| A 必須 | Playback History / Events / boredom / soft delete | `playback-history.sqlite3` のユーザー蓄積データ |
| A 必須 | Track Favorite / Good・Bad / Preference | `track-preferences.json` の正本 |
| A 必須 | Playlist | `playlists.json` |
| A 必須 | Track Identity / fingerprint / firstSeenAt | 再scan後に同じStable Track IDへ再接続するため |
| A 必須 | Track Features | 再解析コストが高くTrack ID参照を持つため |
| A 必須 | 再生位置 / custom start・end / volume adjustment | Track ID別sharded JSON |
| A 必須 | Album・Artist等のお気に入り | `library-favorites.json` |
| A 必須 | EQ / transition / volume normalization / Genre設定 / 表示設定 | 選択したUserDefaults keyを `settings.plist` に保存 |
| B 任意 | Highlight解析結果 | 小容量で再生成可能だが、連続性のためv1では含める |
| B 任意 | Library cache | 再scan可能で旧パスを含むためv1では含めない |
| C 対象外 | 音楽folder bookmark | 再インストール後の権限は再選択して取得する |
| C 対象外 | Artwork / thumbnail / temporary cache / runtime再生状態 | 再生成可能 |
| C 対象外 | 内部Migration/Daily Backup、Analyzer cache、音源 | 役割違い・容量過大 |

## 形式と安全性

`manifest.json` はformat/schema version、アプリ版、ISO 8601作成日時、相対pathとbyte数を持つ。SQLiteはonline backup APIで一貫したsnapshotを作り、JSON、property list、SQLite integrity、曲別調整ファイル名のUUIDを適用前に検証する。stagingを検証した成功時だけ`latest`を入れ替え、旧`latest`を`previous`へ回す。

Restoreは選択フォルダ内の`latest`（または世代フォルダそのもの）を検証し、Application Supportと同じvolume上のpending directoryへ展開・再検証する。次回プロセス起動時、StoreやSQLiteを開く前に現データをrollback directoryへ移してpendingを正本へrenameし、失敗時は元へ戻す。再起動後に音楽フォルダを再選択・scanすると、復元したIdentity registryを使ってTrack ID参照データへ再接続する。一致しないIDは各Storeに残り、別曲へ推測接続しない。
