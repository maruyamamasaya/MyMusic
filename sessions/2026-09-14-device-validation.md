# デプロイ前検証チェックリスト

## 自動テスト・静的確認

- [x] iPhone 17 Pro / iOS 26.5 SimulatorでXCTest 190件（失敗0件）
- [x] iPhone 17 Pro / iOS 26.5 SimulatorでSwift Testing 6件（失敗0件）
- [x] Genre filterとMood Station描画の回帰test 3件（失敗0件）
- [x] Track Preference移行・再読込testを5回反復（失敗0件）
- [x] Analyzer / Semantic Python unittest 38件（失敗0件）
- [x] Analytics Python unittest 52件（失敗0件）
- [x] `git diff --check`（問題なし）
- [x] XCTestDevicesの開始前・終了後確認（新規UUID folder 0件、削除0件、残容量12KB）

## 実機デプロイ

- [x] `./scripts/check-iphone.sh`を実行
- [x] 対象iPhoneのpreflight成功
- [x] iPhone向けbuild成功
- [x] iPhoneへinstall成功
- [x] iPhoneでlaunch成功
- [x] Watch Appのbuild・iPhone Appへの埋め込み・embedded binary validation成功
- [x] Comet上のWatch App install確認
- [x] Watch Appのlaunch成功
- [ ] Watch AppとiPhoneの実機間通信確認

最初のpreflightではscriptの既定対象名が誤記の`Vspera`だったため対象未検出として停止した。正しい端末名は`Vespera`であることを確認し、`AGENTS.md`と両deploy scriptの既定値を修正した。修正後のpreflightは成功し、Vesperaへのbuild・install・launchまで完了した。Cometは最初の試行でnetwork tunnel確立timeoutとなったが、再試行時にtunnel接続、直接install、インストール一覧でのBundle ID確認、launchがすべて成功した。

### デプロイ結果

- Project: `MyMusic.xcodeproj`
- Scheme / Configuration / Product: `MyMusic` / `Debug` / `MyMusic`
- iPhone Bundle ID: `maruyama.MyMusic`
- Watch Bundle ID: `maruyama.MyMusic.watchkitapp`
- Development Team: `U29GY347DY`
- iOS Deployment Target: `26.5`
- iPhone: `Vespera` / iPhone 17e / UDID `00008150-000C54280E33401C`
- Watch: `Comet` / Apple Watch SE / CoreDevice ID `72EDC928-25C2-53C5-BFAC-CA38254ED951`

## 実機で残る操作確認

- [ ] Watch Artworkの初回取得・再試行・到達性復帰
- [ ] Playlistタグ管理、名称変更、削除、割り当て
- [ ] 曲追加時のPlaylistタグfilter保存・復元
- [ ] ライブラリ → 曲のfilter／sort／Artwork非表示
- [ ] ホームのチューニング表示

## 検出して修正した事項

- Genre filterの初期結果を検証するtestで、非同期filter完了を待つようにした。
- Mood Station結果画面の描画fixtureへ、実画面が参照する`ListenLaterStore`を追加した。
- Track Preferenceの旧履歴移行配列を保存前にTrack ID順へ固定し、辞書順序による検証の不安定性を解消した。保存schemaと値は変更していない。
