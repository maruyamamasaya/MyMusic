---
status: completed
date: 2026-08-29
---

# Semantic v2 全library統合export

## 変更

- `semantic.py --export-all`を追加し、default `semantic_cache`と`semantic_workspaces/library-*`の完了済みSemantic v2 JSONを自動検出するようにした。
- 解析cache、Embedding、`index.sqlite3`、resume、差分更新、FIX済みhead計算には変更を加えず、最終JSONだけを読み取る独立したexporterとした。
- sourceごとにowner、scope root、workspace名、schemaVersion、analysisVersion、必須Semantic特徴量、library内relativePath一意性を検証するようにした。
- 空／出力未作成workspaceは理由付きでSkipし、broken／incomplete JSON、同一rootの重複cache、library内path重複はfail closedとして前回merged JSONを維持するようにした。
- workspace更新中は、その旨を表示して直前のatomic確定JSONを使用するようにした。書込み途中のcacheやSQLiteは読まない。
- 異なるmusic-root間のrelativePath衝突はdedupeせず別entryとして保持する。root由来の`libraryId`と各output indexの対応はschema外の`.sources.json` sidecarへ保存する。
- app import用schemaVersion 1 / analysisVersion 2とTrack fieldは変更せず、特徴量値を入力JSONからそのままコピーする。
- `--update`成功と他workspaceの破損を分離するため、自動mergeは追加せず明示的な2コマンド運用を採用した。

## 検証

- export専用Unit Test 8件でdefaultのみ、workspace 1件、複数件、空／未出力、broken／incomplete JSON、relativePath衝突、別libraryの同名file、duplicate root／path、CLI分離を確認した。
- Analyzer全Unit Test 31件が成功した。
- `python3 -m py_compile`、`semantic.py --help`、`git diff --check`が成功した。
- 現在の実workspaceを統合し、default 3,566曲、別ボーカルlibrary 441曲、インスト／OST library 3,837曲、入力／出力合計7,844曲を確認した。cross-library relativePath衝突は0件、`audioReads=0` / `decodeCalls=0`。
- 実行時にインスト／OST workspaceの別update processが動作中だったため、そのsourceは直前のatomic確定JSON 3,837曲を使用した。merged出力とsource manifestのhash、7,844件のsource Track object完全一致を確認した。
- Swift sourceとapp schemaは変更していないためXcode buildは実施していない。

## 制約

- schema v1はmusic-root fieldを許可しない。異なるrootに同一relativePath、fileSize、durationの同一音源がある場合、merged JSONでは両方保持するがiPhone importではAmbiguousになり得る。
- source sidecarは診断・将来migration用であり、現行MyMusicのimport対象ではない。
