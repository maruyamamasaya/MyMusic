---
status: active
date: 2026-09-24
---

# ADR-0008: ライブラリmetadata cacheの全件migrationを例外扱いにする

## Context

MyMusicは約20,000曲のローカルライブラリを想定する。`MetadataService.currentMetadataRevision`は全Track共通であり、値を上げるとquick同期でも旧revisionの全曲がAVFoundation metadata、stream情報、Artworkの再取得へ進む。quick同期はfolder完了時に完成cacheを保存し、途中checkpointを持たないため、中断すると次回も全件処理をやり直す。

2026-09-23にはstream-level音源仕様の追加でrevisionを1から2へ、2026-09-24にはFLACのbit depth復元だけを目的として2から3へ上げた。後者も判定がcodec別ではなかったため、FLAC以外を含む全曲を再取得した。global revisionによる初回scan相当の処理を、影響範囲と再開方法を設計せず2回発生させた。

## Decision

- `currentMetadataRevision`は通常の機能versionではなく、全ライブラリcache migration gateとして扱う。
- 現在値は3に維持する。2へ戻すと、すでに3で保存されたTrackを再び旧revision扱いにして全件再取得を起こすため、rollbackには使わない。
- global revisionを上げてよいのは、ほぼ全Trackへ及ぶ大規模なmetadata意味変更、または既存cacheのdecode／読取／再利用が安全でない障害があり、互換decodeや対象限定migrationでは安全を確保できない場合だけとする。
- codec限定、container限定、特定field限定、分類・表示限定の変更ではglobal revisionを上げない。codec／field別revision、対象Trackだけのrefresh predicate、optional fieldの互換decode、明示的な完全同期などから最小の方法を選ぶ。
- 例外的なglobal migrationには、20,000曲での対象件数・I/O・発熱の評価、途中再開または段階保存、失敗時の旧cache保持、Track UUID／`firstSeenAt`／履歴／Preference／Playlist維持を実装条件とする。
- testでは、更新対象が再取得されることだけでなく、影響を受けないcodecとfieldがcacheを再利用すること、中断後に全件を繰り返さないことを確認する。
- reviewではrevisionの数値変更を定数変更ではなくデータmigrationとして扱い、上記条件とmigration計画がない変更を受け入れない。

## Consequences

形式限定の修正は対象判定や小さなmigration実装を必要とするが、無関係な数万曲の音源読取、発熱、長時間処理を避けられる。全件再取得が本当に必要な変更では準備が増える一方、中断・失敗を前提に安全に進められる。既存revision 3によって開始済みの再取得はこのADRだけでは停止・再開可能にならず、完了後のcacheは引き続き利用できる。
