# 共有Popoverクラッシュ修正

## 作業

- リポジトリ全体の`UIActivityViewController`、`ShareLink`、Popover設定を検索した。
- プレイリスト詳細、データ管理、分析にあった全`ShareLink`を共通`ActivityShareSheet`へ置き換えた。
- `UIActivityViewController`生成時とSwiftUI更新時に、Popoverの`sourceView`、`sourceRect`、矢印方向を必ず設定した。
- 共有用ファイルを一時ディレクトリへ書き出し、共有シート終了後に削除するようにした。
- プレイリストタグの保存処理、PlaylistStore、永続化処理は変更していない。

## 検証

- iPhone 17 / iOS 26.5 Simulator: 全XCTest成功。
- iPad Pro 11-inch (M5) / iOS 26.5 Simulator: `ActivityShareSheetTests` 2件成功。
- Debug Simulator build-for-testing成功。
- 全共有箇所を再検索し、`ShareLink`の残存がないことを確認した。

## 既知事項

- Asset Catalogと既存Swift concurrencyの警告は継続している。今回の変更由来の警告はない。
