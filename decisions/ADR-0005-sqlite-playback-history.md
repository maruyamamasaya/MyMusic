---
status: active
date: 2026-09-01
---

# ADR-0005: 再生履歴の正本を検証済みSQLiteへ移す

## Context

変更ごとに全曲をJSON encode／writeする方式は、20,000曲・長期利用では書込量が履歴全体に比例する。既存JSONには失ってはならないユーザーデータがある。

## Decision

- Apple SDKのSQLite3を直接使用し、外部依存は追加しない。
- 曲累計、日別集計、日別入口、累計入口、生eventを正規化テーブルへ分離する。
- SQLiteファイルの存在ではなく、DB外stateとDB metadataの両方が`verified`であることを正本条件とする。
- 旧JSONを変更せず永久backupを先に作り、transaction import後に全Modelをread-back比較する。失敗／中断時は未verified DBを破棄してJSONから再実行する。
- 通常更新は1曲単位。JSONは24時間単位・7世代の復旧snapshotとし、migration backupは削除しない。

## Consequences

通常書込は全ライブラリではなく変更曲のデータ量に比例する。初回だけ全件load／検証が必要になる。Restore UI、event圧縮、月次集約は将来作業とする。
