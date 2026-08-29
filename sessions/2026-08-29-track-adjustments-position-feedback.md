# Track Adjustments 位置調整フィードバック

日付: 2026-08-29

## 作業

- 開始位置と終了位置のどちらにも使える、現在位置を1秒戻す共通ボタンを追加した。
- 開始位置／終了位置の登録成功時に、対象ボタンを短時間緑色に光らせて「設定しました」と表示するインラインフィードバックとsuccess hapticを追加した。
- 曲変更時はvalidationと成功表示をクリアし、古い曲の状態を引き継がないようにした。

## 検証

- iPhone 17 / iOS 26.5 Simulator: XCTest成功。
- Debug Simulator build: `BUILD SUCCEEDED`。
- `git diff --check`: 成功。
- 既存のSwift 6移行警告とAsset Catalog警告は残るが、今回の変更による新規warningは確認されなかった。

## 未解決・実機確認

- 実機での1秒戻る操作感、success haptic、小画面／最大Dynamic Typeでのボタン配置は未確認。
