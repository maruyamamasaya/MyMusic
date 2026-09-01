# Playback History SQLite移行

## 作業

- SQLite3の正規化schemaと1曲単位transaction upsertを追加。
- 旧JSONを不変のまま永久backupへcopyし、transaction import、全項目read-back比較、外部state＋DB metadataの二重verified判定を追加。
- 起動時24時間条件の日次JSON snapshotと7世代rotationを追加。
- 新規、完全migration、decode失敗、途中DBから再開、差分更新、24時間抑制のXCTestを追加。

## 安全性

- migration前JSONと永久backupは削除・移動・上書きしない。
- `not_started / in_progress / verified / failed`をSQLite外のatomic sidecarに記録し、破損・中断したSQLite単体を正本にしない。
- 検証失敗時は`failed`としてthrowし、SQLite利用へfallbackしない。次回は旧JSONから未verified DBを再作成できる。

## 未検証

- ユーザー指定に従いXcode build、Simulator、実機testは実行していない。追加XCTestも未実行。
- Restore UI、SQLite破損時の自動restore、月別集約、raw event retention／圧縮は未実装。schemaには将来event属性のnullable列を予約した。
