# Xcode検証環境の復旧

- Context Guard: MATCH。Git rootはMyMusic repositoryと一致。
- Xcode 27.1（27A9275）を使用。Metal Toolchainがuninstalledで、既存VisualWorldInstallation.metalのコンパイルが停止していた。
- ユーザーの環境整備依頼により、Apple公式の `xcodebuild -downloadComponent MetalToolchain` を実行。約838.9 MBをdownloadし、27A266aがinstalledになったことと `xcrun --find metal` を確認。
- Simulator／runtimeの追加・更新なし。指定iPhone 17e／iOS 26.5／EB3A49ED-6553-4D7E-B933-387951643EABのみ使用。
- このXcodeの画面操作アプリはDevice Hub（com.apple.dt.Devices）。従来のDeveloper/Applications/Simulator.appは存在しない。Device Hubの一覧から指定Simulatorを選び、画面とAccessibilityを確認できた。
- Metal復旧後、RootViewのHomeView生成式が型推論時間切れになった。homeTabContentと表示用actionを分離し、動作・署名・project設定を維持した。iPhone／埋め込みWatchのDebug build成功。
- 対象XCTestのコンパイルで既存の非UIサービスprotocolがglobal actorへ暗黙隔離され、別moduleのtest actorが適合できないエラーが判明。Sendable＋async契約の10個についてnonisolatedを明示する差分を個別確認。自動承認レビューが当初一括変更を拒否したため適用せず、ユーザーへ差分・影響を説明し「修正してテストまで進める」の明示承認後に適用した。サービス実装actorの隔離は維持。
- 対象: LibraryPersistence、MusicLibrary、TrackIdentity、ListenLaterPersistence、Metadata、TrackPreferencePersistence、PlaylistPersistence、PlaybackHistoryPersistence、LibraryScanCheckpoint、TrackPlaybackAdjustmentPersistenceの各Servicing protocol。
- テスト開始前XCTestDevices: UUID folder 0件、合計12 KiB（既存.DS_Storeのみ）。既存Simulatorアプリ・データは初期化しない。

## 検証結果

- 指定Simulator向けiPhone／Watch Debug build: BUILD SUCCEEDED。
- LibraryGenreFilterTests 6件＋GenreDisplayPresetOrderingTests 1件: TEST SUCCEEDED。
- protocol関連の保存・同期・識別・履歴・ステーション等の10 suite、48件: TEST SUCCEEDED。計55件、失敗0。
- Device HubでMyMusicを操作し、確認用A／Bの追加・複数チェックとN件表示・個別解除・最後の解除・全曲resetを確認。Simulator内には既存のQA音源2曲と今回追加した確認用プリセット2個を保持。実機・Dynamic Type大は未確認。
- git diff --check成功。署名・project設定・Deployment Target変更なし。
- テスト端末作成0台／削除0台。XCTestDevices終了後もUUID folder 0件・合計12 KiB。新規folderがなく削除操作なし。


Apple公式のコンポーネント導入手順: https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components
