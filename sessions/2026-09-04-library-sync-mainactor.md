---
date: 2026-09-04
topic: library-sync-mainactor
---

# 大量ライブラリ同期のMainActor分離

## 変更

- `LibrarySyncService` actorを追加し、folder scanを直列化した。
- ファイル走査、metadata取得、既存差分判定、Track Identity照合、library cache保存、複数folder結合と派生モデル構築をMainActor外へ移した。
- `LibraryStore`は同期状態とfolder単位の完成snapshotだけを更新し、同期中の既存libraryを維持する。
- 既存Track Identityのpath、resource identifier、size／duration、fingerprintの照合順とTrack IDを変更していない。
- scan直列化とファイル名変更時のTrack ID維持を確認するtestを追加した。

## 検証

- iPhone Simulator / generic iOS / iphoneos buildを試行したが、ローカルのCoreSimulator runtime serviceが利用不能で、Asset Catalog処理が`No available simulator runtimes`となり完走できなかった。
- buildが到達した範囲では今回変更ファイル固有のcompiler errorは出ていない。Simulator復旧後の全XCTestとDebug buildが未検証。

## 制約

- LaunchServices / usermanagerdのOS log抑制、再生engine、Track model、ユーザーデータschemaは変更していない。
