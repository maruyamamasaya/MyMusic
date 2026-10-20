# ホームのテーマ切り替え

- Context Guard: MATCH。Git rootはMyMusic。前タスクの未コミット変更を保持。
- HomeViewの左上toolbarへHomeThemeCycleButtonを追加。丸い32pt表示と44ptタップ領域、現在番号とVoiceOver用のテーマ名・循環説明を提供。
- SettingsStore.cycleThemeがAppTheme.allCases順に既存setThemeで反映・保存。順序はシンプルダーク／Living Aurora／Pulse Neon／Blue Cosmos。設定画面で選んだ値も番号に反映。
- 既存の右上再生集計は保持。新しい保存形式・依存・アーキテクチャ変更なし。CURRENT更新。
- 変更Swift 3ファイルのfrontend parseとgit diff --check成功。標準generic Simulator buildはwatchOS 26.5 must be installedで停止。型検証・実機の配置と連続タップ動作は未確認。デプロイなし。
- XCTest未実行。test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。
