# App外バックアップ / Restore基盤

## 作業

- 現行のApplication Support、UserDefaults、cache、security-scoped bookmarkを棚卸しし、`Documentation/ExternalBackup.md`へA/B/C分類を記録した。
- `ExternalBackupService`へbookmark保存・stale更新、SQLite online snapshot、manifest、JSON/plist/SQLite/Track ID検証、latest/previous rotationを実装した。
- Restoreは実行中の正本を触らずpendingへ検証済みデータを置き、次回起動時にStore生成前のrollback可能なatomic swapで適用する。
- Settings > データ管理へ保存先、最終成功日時、復元可否、手動Backup、Restore導線を追加した。
- 空データ、Unicode round trip、2世代rotation、Backup失敗時latest維持、format/missing manifest拒否、Restore拒否時の現データ維持のUnit Testを追加した。

## 検証

- generic iOS device向けbuild: `BUILD SUCCEEDED`。
- generic iOS device向けbuild-for-testing: `TEST BUILD SUCCEEDED`。新規test sourceのコンパイル成功。
- Simulator test実行: ローカル環境にSimulator runtimeがなく未実施。
- 標準Simulator build: Watch AppIconのapplicable content不足で失敗。AppIconをコマンド上で無効化した場合もWatchKit runtime不在で失敗したため、generic iOS deviceで代替検証した。
- `git diff --check`: 成功。

## 未解決 / 手動確認

- 実機でiCloud Drive選択、Files表示、bookmark再アクセス、Backup/Restore、Library再選択を確認する。
- アンインストール前にBackup内容を確認したうえで、アンインストール→再インストールの最終確認を行う。
- 自動Backupは手動経路の実機安定後に、backgroundまたは1日1回を候補として検討する。再生eventごとの外部書込は行わない。
