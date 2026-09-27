---
status: completed
date: 2026-09-26
---

# Flow MixとTime Capsule

## 作業

- Flow Mixを追加し、直近再生の解析済み曲から音響特徴の近い曲へ最大25曲を順につなぐようにした。
- Time Capsuleを追加し、1〜3年前の同日±45日に再生した曲から直近60日を除いて最大25曲を構成した。
- Flow／Time Capsuleは対象がない場合にタイルを非表示にした。
- Daily Mix、My Favorites Mix、Flow Mix、Time Capsule用の抽象画を生成し、1024px JPEGとしてAsset Catalogへ同梱した。
- Home snapshotへTrack Featureのcopy-on-write snapshotを追加し、特徴値の抽出とMIX計算はworker actor上で行うようにした。

## 検証

- 既存iPhone 17e Simulator 1台、並列無効で`MixSelectionServiceTests` 8件と`HomeRepresentativeTrackPolicyTests` 6件、合計14件が成功した。
- generic iOS Simulator Debug buildが成功した。
- Vespera（iPhone 17e）向けDebug build、install、launchが成功した。端末ロック由来のnotification service警告は出たが、デプロイ結果には影響しなかった。
- テスト前後とも`XCTestDevices`は新規UUID folder 0件、合計12KBで、作成・削除したtest端末は0台だった。
- 既存の`MusicHistoryView`のSwift 6 async警告とApp Intents metadata警告は残っている。

## 未解決事項

- 実ライブラリでのFlowの遷移感、Time Capsuleの候補量、4枚のタイル画像の見え方は未確認。
