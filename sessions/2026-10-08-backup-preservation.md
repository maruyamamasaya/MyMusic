# バックアップ保全と隔離復元検証

- Context Guard MATCH。両Git root/共通契約revision 3一致を確認。HomeStereo変更もユーザーから明示依頼。実データ/稼働アプリは変更していない。
- MyMusic Semantic cacheへbackup create/restore CLIを追加。cache lock、SQLite snapshot、全file manifest/hash、embedding参照確認、新規先限定restore。既存archive/cacheを上書きしない。
- Analyzer 40 tests成功（backup往復、破損/path拒否を含む）。iPhoneコード/保存形式は変更なし。
- MyMusic履歴の現行Serviceをswiftcで直接compileして/private/tmpの隔離fixtureで実行。Track ID/Calendar補助定義のみ代替。backup→pending apply直後はPlaybackHistory Model一致、production Persistence.load後は空に再作成された。修正保留指示を維持する。
- HomeStereoはJSON v2 state snapshotと次回起動restoreを追加。SQLite v14全table、feature、原本/解析run、選定settingsを保全。旧JSON v1互換と既存tags/連携ID保持。
- HomeStereo verify full: XCTest 139（3 skip）、Swift Testing 85成功、macOS BUILD SUCCEEDED。隔離testで代表10table全field、ID/曲順/item ID/tags/評価/詳細event/link/集計/fingerprint/features/音量/settings/原本一致と退避を確認。
- 文書: CurrentDataPreservationMapを現行へ更新、Semantic README、CURRENT/ARCHITECTUREに追記。開始前からある文書変更・他作業の新規文書は維持。
- 実cache全量、別Macでの音源権限再設定、大容量backup、アプリUI操作は未検証。embedding保全は明示CLIであり自動backupではない。履歴・再適用UIは今回未実装。
- iOS Simulator/Xcode testなし、Simulator/test端末作成・削除0。macOS Swift Package testsのみ。終了時XCTestDevices合計12K、削除なし。デプロイ/commitなし。
