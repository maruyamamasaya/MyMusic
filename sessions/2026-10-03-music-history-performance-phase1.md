# 音楽史の性能改善 Phase 1

## 作業

- 影響の小さい改善から進める依頼に対し、不要なAnalytics集計の除去だけを実施した。
- `AnalyticsService`の既存event変換・sort・日月group化を`makePlaybackMonths`へ抽出し、Analytics全snapshotと音楽史で共有する。
- `MusicHistoryView`は全Analytics snapshotの代わりに月groupだけを要求する。直近7／30日の集計、評価／非表示曲一覧などを生成しない。
- View／Store／Serviceの責務、MainActor境界、履歴日時、ランキング上限、カードの表示・生成タイミング、再生queue、保存形式は変更していない。
- CURRENT／ARCHITECTUREへ現状と共有生成経路を追記した。既存の未コミットWatch変更は保持した。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`。
- 最初のsandbox buildは既存cacheの書込権限で失敗し、権限拡張した同コマンドで成功した。
- `git diff --check`成功。diffで既存event変換・sort・group化が同じであることを確認した。
- ロジックを変更しない抽出と呼び出し切替のため、今回はbuild検証と差分確認に限定し、XCTestは実行しなかった。test端末の作成・削除は0台。XCTestDevicesの容量確認・削除は行っていない。

## 制約・未解決

- 既存のMusicHistoryViewカード生成のSwift 6 async警告、App Intents metadata警告は残る。
- 実機の表示時間／CPU／体感改善は未計測。実機デプロイは未実施。
- 同期集計のMainActor占有、未表示詳細の先行生成、カード待ち、再集計・revisionの改善は後続候補とする。
