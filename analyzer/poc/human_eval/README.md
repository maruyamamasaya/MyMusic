# 人間評価サンプルを用いた最小head修正

2026-08-28。指定曲5曲 + DAZBEE 3曲 + AZKi 3曲 = 11曲だけ。
結果は `output/report.md`（全特徴量・before/after・各分類器raw上位10）、`output/summary.json`。
**本番昇格しない。バトルアリーナのVocal誤判定が残るため、V/I head再検討を推奨。**

## 対象特定と安全性

`samples.json` は今回の評価用選曲と人間の認識の記録。モデルへの入力・学習データではない。
本番SQLiteはWALを持っていたため**接続しない**。保存済み `music_features.json` の559件から
Artistと完全なTitleで候補を列挙し、1件だけの場合に採用する。重複/未発見では候補パスを示して停止する。
既知のrootと相対パスを使い、size/更新日時を検証し、mtimeNSを固定する。ライブラリの再帰探索は行わない。

- Showは指定どおり国立競技場2024版。武道館2023版は採用しない。
- ラスボス戦は「ファイナル」版。通常版は採用しない。
- DAZBEEは360°、Departures、Forフルーツバスケット。
- AZKiはSincerely、たばこ、Just Be Friends -piano.ver-。
- 曲名・Artistは選曲/表示専用。`HeadBank.predict()` が受け取るのは数値Embeddingだけ。
- `review.json` は調査後の定性的評価文で、分類やJSON exportへは使用しない。
- 前回20曲PoCのSQLite/JSONも変更しない。新しい `human_eval/data/` と `human_eval/output/` だけへ保存。
- 本番SQLite本体/本番JSON/前回PoC SQLite/JSONはSHA-256の前後一致で確認。WALは触らず別プロセスに任せる。
- iPhone、Badge閾値、Selection、Playback、schemaは変更しない。

## 確認結果と選択した微修正

現在のv2で11曲を一度だけデコード・解析。既存の平均mono/soxr/3×30秒方式を維持し、
raw labelに加えpatchごとの1280次元Embeddingを小さなNPZへ保存した。
その後は**音源を読み直さず**同じEmbeddingに分類headを適用し、入力の差がないbefore/afterを比較した。

|出力|旧mapping|今回のmapping|
|---|---|---|
|vocal|Jamendo top50 `voice`|専用 `voice_instrumental` の `voice`|
|instrumental|なし|同じ専用headの `instrumental`|
|aggressive|なし|専用 `mood_aggressive` の `aggressive`|
|calm|Jamendo `calm`|専用 `mood_relaxed` の `relaxed`|

共有Discogs-EffNetは変更しない。追加headは約0.514MBずつ、計約1.54MB。
すべて学習済みsoftmaxを各patchで取得→算術平均→小数6桁。係数調整・再学習・強制正規化はなし。
Instrumentalは学習済み2クラス出力であり、汎用タグの `1-voice` ではない。
CalmとAggressiveは独立したheadで、互いの反転値ではない。
Calmは曲全体のrelaxed傾向で、声の柔らかさそのものではない。
EnergyはDSP、energetic/softはraw model labelとして区別。性別やライブ検出器は作っていない。

Electronic/Piano/Ambient/DnB/Dark/Energy/Tempoは値も含めて変更なし。Brightは引き続き未出力。
Darkは既存のMood `dark` をそのまま残し、復活用のDSP式や補正は追加しない。
PoC用JSONはschemaVersion 1 / analysisVersion 2の既存形式。今回**本番Importはしない**。

一次資料:

- [Vocal / Instrumental head](https://essentia.upf.edu/models/classification-heads/voice_instrumental/voice_instrumental-discogs-effnet-1.json)
- [Aggressive head](https://essentia.upf.edu/models/classification-heads/mood_aggressive/mood_aggressive-discogs-effnet-1.json)
- [Relaxed head](https://essentia.upf.edu/models/classification-heads/mood_relaxed/mood_relaxed-discogs-effnet-1.json)

これらは小規模MTG学習集合の分類器。公式CV指標はこのライブラリでの精度を保証しない。
MTGモデルのライセンスは [CC BY-NC-SA 4.0](https://essentia.upf.edu/models.html)。重みはGitに含めない。

### 誤判定を補正しなかった理由

「対戦！バトルアリーナ」は専用headでもVocal 0.791 / Instrumental 0.209。
3区間すべてでVocalが高く、patch中央値0.852なので単一外れ値ではない。
モデルの学習対象とゲームBGMの音色の違い等が候補だが、原因は確定していない。

同じEmbeddingを使う[MTT head](https://essentia.upf.edu/models/classification-heads/mtt/mtt-discogs-effnet-1.json)
約2.73MBも追加診断した。バトルアリーナはvocal 0.042 / no vocals 0.044で双方低く、明確な解決にならなかった。
MTTは**診断専用・最終mappingには不採用**。同義タグの比率を調整したり、曲名/Genreによる例外を作らなかった。
診断結果は `output/mtt-diagnostic.json` と全曲レポートに保存。

低音検証では、飽和しやすい旧bassスコアとは別に20–250Hzと20–120Hzの未clamp power比を記録した。
ChroNoiR曲はそれぞれ約0.579 / 0.508。ただしベース楽器も含む曲全体の比率で、声のピッチや性別を推定する値ではない。

## 実行（リポジトリrootから）

既存の専用venvを再利用し、Python依存を増やしていない。

```sh
# 既存の固定11曲だけ。2回目以降は成功済みをSkip。
analyzer/poc/.venv/bin/python -B analyzer/poc/human_eval/benchmark.py --stage baseline

# 新規ネットワーク取得はこのコマンドだけ。既存headはchecksum確認してSkip。
analyzer/poc/.venv/bin/python -B analyzer/poc/human_eval/prepare_heads.py --diagnostic-mtt

# 保存済みEmbeddingのみ。モデルが同じなら結果もSkip。
analyzer/poc/.venv/bin/python -B analyzer/poc/human_eval/benchmark.py --stage heads
analyzer/poc/.venv/bin/python -B analyzer/poc/human_eval/compare_mtt.py

# 保存済み結果だけを使う。
analyzer/poc/.venv/bin/python -B analyzer/poc/human_eval/benchmark.py --stage report

cd analyzer/poc/human_eval
../.venv/bin/python -B -m unittest -v test_human_eval
```

`--stage baseline --limit 2` のような部分実行、Ctrl+C後の再開も可能。
全11曲のbaselineが揃うまではhead比較を開始しない。新しい曲への自動拡張はしない。
NPZは音源ではなく、この11曲のhead比較用中間値。数万曲のEmbedding exportやキャッシュ移行は実装していない。

## 検証結果

- 既存Analyzer 6件 + 既存PoC 9件 + 今回の評価用4件、計19テスト成功。
- baseline再実行は11件Skip。head再実行も11件Skip、音源読み込み0件。
- Import JSONの既存validatorを通過し、照合metadataは元JSONと完全一致。
- 本番2ファイルと前回PoC2ファイルのSHA-256一致。変更範囲は `analyzer/poc/` のみ。
- Swift変更なし。今回はXcode Build・iPhone実機検証は対象外。

11曲のbaseline測定は平均4.165秒/曲、PythonプロセスのピークRSSは約489MiB。
追加headの処理は保存済みEmbeddingから平均0.0034秒/曲。モデル初期ロード時間は別計測。
既存入力frontendとnative Essentiaの数値パリティは未確認で、正式採用前の検証事項として残る。

## 評価の限界と次段階

8曲は概ね一致、2曲（360°/ブラッディ・グルービー）は部分一致、1曲（バトルアリーナ）は明らかに不一致。
**全評価曲で最低条件を達成したとは言わない。**
Vocalのraw値改善だけでなく、InstrumentalへVocal Badgeを付ける誤検出を重く扱い、559曲への昇格は見送る。
まずV/I headまたは入力frontendを独立した少数の正解付き音源で再検証するのが次段階。
同じ11曲に合わせた係数学習は行わない。この集合は判断に使用した開発集合であり、汎化精度のテスト集合ではない。
