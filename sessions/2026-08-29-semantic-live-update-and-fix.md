---
status: completed
date: 2026-08-29
---

# Semantic v2 ライブ更新と最終特徴量FIX

## 変更

- `semantic.py --update`を通常運用入口とし、保存済み音楽Rootを毎回再帰走査するようにした。
- NFC正規化した`relativePath`をidentityとして、fileSize / mtimeNSが同じ既存Trackはmetadata読取とEmbedding生成をSkipするようにした。
- 新規Track、新規Artist / Album subfolder、更新Trackだけを音声読込し、削除TrackはSQLiteの`present=0`で履歴とNPZを保持しながらexport対象から除外するようにした。
- Embedding profileとhead profileを分離し、head再評価では保存済みEmbeddingだけを使用して`audioReads=0`とした。
- 1曲単位のcheckpoint、atomic JSON、Ctrl+C後の再開、sharded NPZ、20,000行reconciliationを実装・testした。
- production `music_features.json` / `analyzer/cache/analysis.sqlite3`、PoC dataと書込境界を分離した。
- インスト／OST中心3,837曲、従来3,552曲、追加ボーカル中心441曲を保存済み出力とEmbeddingだけで評価した。
- Minecraft、Zelda、Pokémon原曲、Monster Hunter、NieRを評価用にgroupingし、分布、閾値超過率、Pearson / Spearman相関、group差、patch分布を確認した。group名は推論や補正には使用していない。
- 大規模なVocal / Instrumental分離とインスト内部の特徴量差が成立し、教師ラベルなしのglobal補正は回帰リスクが高いため、calibrationを追加せずraw headをSemantic v2としてFIXした。
- `CURRENT.md`、`ARCHITECTURE.md`、`analyzer/SEMANTIC_README.md`、`analyzer/SEMANTIC_CALIBRATION_REPORT.md`へ運用、境界、評価結果、既知制約を記録した。

## 評価要約

- インスト／OST中心: `instrumental`中央値0.844、`vocal > 0.5`は11.1%。後者には実際のボーカルを含むアニメ／OST群が混ざるため誤判定率とは扱わない。
- Minecraft: 119曲すべて`vocal <= 0.5`、`instrumental`中央値0.928、`ambient`中央値0.323、`calm`中央値0.970。
- Zelda: `vocal > 0.5`は3.3%。戦闘語群は静穏語群よりaggressive / darkが高く、calm / pianoが低かった。
- 従来ボーカル中心: 3,552曲の95.3%が`vocal > 0.5`、中央値0.920。
- 9次元Semantic vectorは3,837曲中3,836個が一意。calm / ambient等は相関するが同一特徴量にはなっていない。
- 既知誤判定「対戦！バトルアリーナ」は3区間すべてVocalが高く、単純なpatch外れ値やmean集約だけでは説明できない。game / OST音色に対するvoice headの局所的domain shiftを残存制約とした。
- 16曲は0.997〜2.038秒で、2.048秒の最小model patchを構成できず安全にerrorとなった。
- 新規dynamic workspaceの`energy` / `tempo`はproduction DSP baselineがないため未出力。Semantic側では推測・再解析しない。

## 検証

- `PYTHONPATH=analyzer analyzer/poc/.venv/bin/python -m unittest discover -s analyzer/tests -v`: 23件成功。
- 疑似ライブラリtestで既存3曲Skip、新規root曲1曲と新規subfolder曲1曲だけ`audioReads=2`、再実行は5曲全Skip / `audioReads=0`、head強制再評価は5曲成功 / `audioReads=0`を確認した。
- 更新Trackは対象1曲だけ再Embedding、削除Trackは一度だけ検出されexportから除外、再実行では削除0件を確認した。
- Ctrl+C後のNPZ回収とhead中断後の再開、既存frozen SQLite migration、20,000Trackの初回insertと再実行全unchangedを確認した。
- patch診断17曲は保存済みEmbeddingへheadを再適用し、全件でexportのVocal値と1e-6未満で一致。音源読込0。
- `python3 -m py_compile ...`: 成功。
- `analyzer/semantic.py --help`: `--update`入口を確認。
- `git diff --check`: 成功。
- production JSON、production SQLite、PoC 249ファイル、既存Semantic output 3件のhashを確認し、評価・test中にcache/outputの更新時刻変化がないことを確認した。
- Swift sourceは変更していないためXcode buildは実施していない。

## 未解決事項

- 個別のgame / OST曲に対するVocal誤認は残る。作品横断の人手ラベル付き評価セットが用意できるまで再calibrationしない。
- 2.048秒未満の音源と、新規Trackのenergy / tempo生成は今回のSemantic head FIXの範囲外。
