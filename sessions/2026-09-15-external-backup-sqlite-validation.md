# App外バックアップ SQLite検証エラー修正

## 作業

- 初回のApp外バックアップで再生履歴DBの整合性エラーになる経路を再現し、online backup後の単体DBにWAL modeが残ってread-only integrity checkが存在しない`-wal` fileを要求することを特定した。
- Files / iCloud DriveのFile Provider配下でSQLiteを直接作成・検証せず、ローカル一時領域でonline snapshotとintegrity checkを完了してから通常ファイルとしてcopyするよう変更した。
- online snapshotを単体ファイルとして扱えるよう、backup完了後にDELETE journalへ正規化した。
- online backup中の一時的な`SQLITE_BUSY` / `SQLITE_LOCKED`を最大5秒retryするようにした。
- 接続を開いたままのWAL databaseをsnapshotし、内容とmanifestを検証するtestを追加した。

## 検証

- Generic iOS Device向け署名なしDebug build: `BUILD SUCCEEDED`。
- 既存のboot済みiPhone 17 Pro Simulator 1台を使い、並列testを無効にして`ExternalBackupServiceTests`を実行: `TEST SUCCEEDED`。
- 追加testにより、接続中のWAL databaseを単体snapshotへ変換し、保存内容とmanifestを再検証できることを確認した。
- 通常のSimulator buildは既知のWatch用AppIcon content不足で停止したため、target固有SDKを使うGeneric iOS Device buildで代替した。

## 未解決 / 手動確認

- 実機のFiles / iCloud Drive保存先で、初回バックアップと2世代rotationを確認する。
