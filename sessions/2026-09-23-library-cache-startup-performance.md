# Library cache startup performance

## 目的

約10,000曲かつ複数folderのlibraryで、起動時cache復元の重複I/O、JSON decode量、保存容量を減らす。

## 変更

- `LibraryPersistenceServicing`へ複数folderの一括loadを追加した。既存test doubleは既定実装で互換を維持し、実サービスはcache fileを1回だけ読む。
- cache schema v2を追加し、folder pathとTrack配列だけをcompact JSONへ保存する。毎回再構築するAlbum／Artist／Genre／Composerは保存しない。
- 旧Store／旧単一SnapshotをTrack配列へ変換して復元し、次回saveでv2へ自然移行する。
- `LibraryStore.restoreAndLoadIfNeeded()`は全folderのcacheを一括取得し、cache欠落folderだけをscanする。

## 検証

- generic iOS Simulator Debug build: 成功。
- `TrackFirstSeenAtTests`: 8件成功。v2の複数folder round-trip、派生配列非保存、旧Store読込、Track ID／`firstSeenAt`／file URL復元を確認。
- test前後の`XCTestDevices`はUUID folder 0件、合計12 KB。新規test端末の作成・削除は0件。
- 専用lint設定は確認されていない。

## 未確認

- 実機約10,000曲でのcold launch時間、cache file容量、peak memoryの変更量。
- 今回は実機deployを依頼されていないため未実施。
