---
status: completed
date: 2026-08-29
topic: single-track-playback-reset
---

# 1曲ごとの再生履歴リセット

## 作業

- 分析画面の「よく再生している曲」に長押しメニューを追加した。
- 対象曲名、削除対象、取り消せないことを示す確認アラートを追加した。
- `PlaybackHistoryStore` に1曲単位のリセットを追加し、再生回数、再生イベント、最終再生日時だけを消去するようにした。
- お気に入り、再生傾向評価、飽き度、シャッフル除外は保持する回帰テストを追加した。

## 検証

- XCTest: iPhone 17 Simulatorで`PlaybackHistoryResetTests` 1件が成功。
- iPhone Simulator Debug build: `BUILD SUCCEEDED`。既存のAsset CatalogとSwift 6 concurrency関連のwarningは残るが、今回変更のerror / warningはなし。
- `git diff --check`: 成功。
- `git diff` / `git status`: 既存のAlbum Artist / 検索作業の未コミット変更を保持し、今回対象のファイルだけを追加・変更した。

## 制約と未解決事項

- 全曲一括リセットは意図的に実装していない。
- リセット完了後は対象曲が「よく再生している曲」から消える。
