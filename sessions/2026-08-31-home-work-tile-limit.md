# ホーム作業用タイルの表示上限変更

## 作業

- ホームの作業用欄を最大12枠へ拡張した。
- 1枠目の全対象曲再生を維持し、2〜11枠目へ最大10件の作業用プレイリストを表示する。
- 11件以上の作業用プレイリストがある場合は、12枠目を既存の「続きを見る」として専用一覧へつなぐ。
- 表示上限と「続きを見る」の境界をUnit Testへ追加した。

## 検証

- iPhone 17 / iOS 26.5 Simulator: 全XCTest 79件成功、失敗0、skip 0。
- iPhone Simulator Debug build: `BUILD SUCCEEDED`。
- 既存のAssets／Swift 6移行関連warningのみで、新規warningは確認されなかった。

## 未解決事項

- なし。
