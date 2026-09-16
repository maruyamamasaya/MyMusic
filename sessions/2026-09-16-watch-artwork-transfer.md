# Watch Artwork転送の整理

## 作業

- 現在曲のArtwork identifierをWatch再生状態へ追加し、同一Trackで画像が更新された場合もWatchの保持画像を破棄して再要求する。旧stateのidentifier欠落は引き続き受理する。
- 転送fileにもArtwork identifierを付け、到着順が前後した古い画像をWatchへ適用しない。
- iPhone側は同じ画像の転送中要求を1件にまとめ、曲変更時には古い転送を取り消す。転送完了時と準備後の取消時に一時fileを削除する。
- Watchの画像待機を30秒へ変更し、転送が遅いときの重複要求を減らす。最大3回の再要求を維持する。
- Library全体のArtworkはWatchへ複製せず、現在曲の画像だけをメモリに保持する。

## 検証

- iOS Simulator宛先を明示したMyMusic scheme build成功。Watch targetも含む。
- `WatchPlaybackMessageTests`の限定XCTest成功。既存Simulatorを1台使用し、並列testは無効。
- `git diff --check`成功。
- `XCTestDevices`は開始時と終了時ともUUID folder 0件、合計12KB。作成・削除したtest端末は0件。

## 未検証

- 実機間の転送所要時間、転送取消、通信断時の再要求は未検証。30秒の待機値は実機測定後に調整する。
