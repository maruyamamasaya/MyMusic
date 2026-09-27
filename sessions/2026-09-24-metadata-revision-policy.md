# Library metadata revision運用方針

## 調査

- `6be5986 Fix FLAC Hi-Res metadata detection`はFLACのbit depth復元を目的にglobal metadata revisionを2から3へ更新した。
- quick同期のcache再利用判定は全Trackで同じrevisionを比較するため、FLAC以外を含む旧revisionの全曲がAVFoundation metadata再取得へ進んだ。
- 2026-09-23のstream-level音源仕様追加でもrevisionを1から2へ上げており、全件再取得は今回が2回目だった。
- quick同期は途中checkpointを持たず、folder完了前の中断では旧cacheが正本のままなので、次回も全件処理を繰り返す。

## 決定

- ADR-0008を追加し、global revision更新を大規模な全Track移行またはcache読取障害で選択的migrationが不可能な場合だけに限定した。
- codec／field限定変更ではglobal revisionを上げず、対象限定refresh、codec／field別revision、互換decodeを使用する。
- 例外的な全件migrationには20,000曲での負荷評価、途中再開、ユーザーデータ参照維持、未影響形式の回帰testを必須とする。
- 現在値3は維持する。値を2へ戻すとrevision 3で保存済みのTrackを再び全件再取得するためである。

## 変更

- `ARCHITECTURE.md`と`CURRENT.md`へ事故内容と運用条件を記録した。
- `MetadataService.currentMetadataRevision`の直上にADR参照と全件影響の警告を追加した。

## 検証

- 文書とコメントのみの変更。Xcode build／testは実行していない。
- `git diff --check`でMarkdownとソースコメントの差分を確認する。
