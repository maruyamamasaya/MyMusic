# Visual World の独立設定

- 設定のデザインに「再生中のビジュアル」を追加し、5種類をテーマとは別に選択・保存できるようにした。
- 旧設定は最初の起動時に選択中のテーマ相当の種類を保存する。以後テーマ変更から独立する。
- 選択はApp外バックアップの設定に含める。描画のMetal／Canvas双方が同じ選択を参照する。
- 「薄明」を5番目の選択肢として追加。MetalとCanvasで夜明け前の空、暖色の地平線、ゆっくり流れる雲の層を描画する。
- 全種類の音反応を見直した。球体の外形は固定し、内部の発光とAuroraの光帯を強化。Pulse Neonは音域でゲート発光、Blue Cosmosは星雲と瞬く星、薄明は暖色の空・地平線・雲の速度へ曲の値を反映する。MetalとCanvasの両経路を更新した。
- アート画面の左上に5種類の選択メニューを追加。設定ページと同じ`SettingsStore`の選択を更新し、右上の通常画面切り替えは維持する。
- 左上メニュー追加後、`xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`が成功。Vesperaへの再デプロイでbuild、install、launchも成功。メニューの実機操作は未確認。
- アート画面の下部をジャケットアイコン＋5操作に簡略化。前へ・再生／一時停止・次へ・いいね・グッドのみ常時表示し、旧詳細パネルと背景gestureの入口を表示しない。
- 簡略化後、iPhone generic Debug buildが成功。Vesperaへ再デプロイし、build・install・launchが成功した。5操作の実機タップ確認は未実施。
- 追加操作としてアート画面のボタン以外の全域に排他的な1回／2回タップを配置。1回は再生／一時停止、2回はいいね。明示ボタンのタップとの二重実行を避ける。
- ジェスチャー追加後のiPhone generic Debug buildと`git diff --check`が成功。実機でのタップ競合確認は未実施。
- Vesperaへの再デプロイでbuild・install・launchが成功した。1回／2回タップの実機操作と下部ボタンとの競合は手動確認対象。
- `git diff --check`と変更Swiftファイルの構文解析は成功。Simulator buildはWatch AppIconに適用可能な画像がないため失敗。ビルド時だけアイコン指定を外した再試行もWatchKit依存を解決できず失敗し、Swiftの型チェック結果は未確認。Metal単体コンパイルもMetal Toolchainが未導入のため実行不可。`xcodebuild test`は実行していない。
- 未解決: Simulator向けのWatch側アセットエラー、単体Metalコンパイル用Toolchain未導入。Visual Worldの実機表示は未検証。

## 実機デプロイ

- `./scripts/check-iphone.sh`でVespera（iPhone 17e、UDID `00008150-000C54280E33401C`）の接続、ペアリング、Developer Modeを確認した。
- 初回の`./scripts/deploy-iphone.sh`は`SettingsStore`初期化中の`self`参照によるSwiftコンパイルエラーで停止。選択値をローカル変数へ移して修正した。
- 再実行で`MyMusic.xcodeproj`／`MyMusic`、product `MyMusic`、Bundle ID `maruyama.MyMusic`のDebug実機ビルド、install、launchがすべて成功した。既存の作業ツリー変更は保持した。
- `xcodebuild test`は実行していない。`XCTestDevices`の新規作成・削除は0台。実機でのVisual Worldの目視確認と熱・電力の長時間評価は未実施。
