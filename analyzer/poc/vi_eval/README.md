# Vocal / Instrumental追加評価（2026-08-29）

結果: `output/report.md`。今回15曲だけ解析し、前回11曲は保存Embeddingで回帰確認した。
Vocal 5/5、Instrumental 8/9（Hard Caseを含む）、Mostly Instrumentalは別評価。
推奨は **A: 559曲の評価へ進める**。本番採用の承認ではなく、559曲解析を今回実行したわけではない。
電子系BGMの「ワールドチャンピオンシップ戦」「対戦！バトルアリーナ」は誤判定が残る。

## 安全境界

- 本番JSONの保存済み3,552件のmetadataだけから候補を選び、15曲に固定。音楽rootを再帰検索しない。
- `samples.json` のArtist/title/album/pathは選曲・Ground Truth専用。推論にはPCM/Embeddingだけを渡す。
- supercell「さよならメモリーズ」は2候補のためAmbiguous除外。別Artistのカバーへ代用しない。
- サザンの依頼表記「シンドバット」に対し、保存名「シンドバッド」・同Artist・2024 Remasterパスを確認し、表記差を記録。
- `fileSize`、更新日時、root内のパス、iCloud dataless有無を確認し、音源の変更があれば停止。
- 本番SQLiteは接続しない。本番JSON/SQLite、前回20曲/11曲の保存ファイルをSHA-256で前後確認。
- 既存処理を停止・上書き・修復しない。外部変更を検出した場合も差し戻さず報告する。
- 1曲ごとのatomic checkpoint。成功済みはSkip。出力先を外部指定するオプションはない。
- 559曲/2万曲へ拡張するオプションなし。今回の書込はこのディレクトリとPoC README/.gitignoreのみ。
- iPhone、Playback、Selection、Badge threshold、JSON schema、本番requirementsは変更なし。
- 生成物/ネイティブ依存はGit対象外。診断JSONはMyMusic Import用JSONではない。

## 何を確認・修正したか

重み/head/mappingは前回のまま。3区間それぞれのSoftmax、全patch出力、最終meanを保存。
`mean / median / max / p90 / p95 / Voice優勢patch割合 / 区間平均のmedian` を比較した。
maxや高percentileは「最後の歌」をVocal扱いへ引っ張る。medianでも電子系BGM誤判定は解消しない。
したがって平均集約・mapping・閾値は変更していない。

公式native Essentiaでfrontendを比較し、EOFに到達する最後の中心frameが1つ足りない点を確認した。
修正候補は `frontend_candidate.py` に隔離。既存Engineを凍結したまま、prefixはbit一致、追加frameだけを計算する。
8種の合成入力でnativeとframe数一致、mel値の最大絶対差は0.000180未満。
今回の全30秒区間は修正後も29patchであり、追加frameが推論に使われないことを確認した。
よって保存Embeddingからheadを再評価でき、追加15曲/回帰11曲の特徴量差は0。
この修正は観測したV/I誤判定を改善するものではない。

native検証の範囲は**同じ16kHz PCMに対するmel抽出**。
native decoder/resamplerとのbit一致、TensorFlow対ONNXの完全一致、streamingの無音noise付加は未検証。
Vocal確率やVoice優勢patch割合を「人声の時間占有率」として解釈しない。
「最後の歌」は90秒/475.55秒（約18.9%）だけ観測しており、人間の約5%という時間比率は検証していない。

## ファイル

|ファイル|責務|
|---|---|
|samples.json|評価用の対象とGround Truth。分類用ルールではない|
|evaluate.py|安全な選曲・逐次解析・patch/head保存・回帰/再比較|
|frontend_candidate.py|末尾frame修正候補のみ。既存baselineを変更しない|
|audit_frontend.py|公式native Essentiaとの合成信号によるパリティ検証|
|report_vi.py|保存結果から表・集約比較・全rawラベル等のレポート生成|
|test_vi.py|照合、出力隔離、集約、境界、再開、非変更のテスト|
|requirements-native.txt|native検証だけの依存を固定|
|data/|固定manifest、1曲単位JSON/NPZ、実行履歴|
|output/|baseline/comparison/regression/frontend-audit/protection/report/summary|

## 実行（リポジトリrootから）

前回の `analyzer/poc/.venv`、モデルをそのまま使用。headの再ダウンロードは不要。

```sh
# metadataのみ。作成済みなら固定manifestを再利用する。
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage select

# 初回2曲、続き、全完了後は15件Skip。
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage baseline --limit 2
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage baseline

# 一度だけ必要。既存venvのpackageを変更しない--target隔離。
# CPython 3.12 / Apple Silicon / macOS 15以降。
analyzer/poc/.venv/bin/python -m pip install --no-cache-dir --no-deps \
  --target analyzer/poc/vi_eval/.native -r analyzer/poc/vi_eval/requirements-native.txt

# 以下は実音源を読まない。
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/audit_frontend.py
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage compare
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage regression
analyzer/poc/.venv/bin/python -B analyzer/poc/vi_eval/evaluate.py --stage report

cd analyzer/poc/vi_eval
../.venv/bin/python -B -m unittest -v test_vi
```

Ctrl+C/SIGTERM後も同じbaselineコマンドで再開。失敗曲は次回再試行する。
baselineのconfigや保存Embeddingが変わった場合はエラーにし、勝手に上書き再解析しない。
`compare` は修正候補が使用patchを変えないと検証できた曲だけで成立する。短い曲などでpatch数が変われば停止する。

## 検証

既存Analyzer 6件、既存PoC 9件、今回8件、計23テスト成功。
実データは2曲→残り13曲→15件Skipを確認。割込み再開は合成テストでも検証。
前回human_evalのintegration testは古い本番snapshotを前提にし、前回生成物へ書くため今回は実行せず、読み取り専用の新しい回帰検証で代替。
Swift変更はなくXcode Build対象外。

## 一次資料

- [V/I head出力・学習集合](https://essentia.upf.edu/models/classification-heads/voice_instrumental/voice_instrumental-discogs-effnet-1.json)
- [MusiCNN frontend](https://github.com/MTG/essentia/blob/master/src/algorithms/spectral/tensorflowinputmusicnn.cpp)
- [FrameCutter](https://github.com/MTG/essentia/blob/master/src/algorithms/standard/framecutter.cpp)
- [Essentia 2.1b6.dev1389配布](https://pypi.org/project/essentia/2.1b6.dev1389/#files)

前回調査の「Mac wheelなし」は不正確だった。今回使った公式リリースにはCPython 3.12/macOS arm64のwheelが存在する。
EssentiaライブラリはAGPL、モデルは従来通りCC BY-NC-SA。今回の検証用依存を本番へ組み込んだわけではない。
