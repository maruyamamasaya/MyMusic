# MyMusic Analyzer v2 — 隔離PoC

v1の意味分類式を調整するのではなく、学習済みモデルの出力を実音源で比較する実験。
本番採用や559曲への展開を自動で行うツールではありません。
測定結果と最終判定は `EVALUATION.md`、曲別の全スコア・上位5ラベルは `output/report.md` を参照。

2026-08-28の指定11曲による追加検証は `human_eval/README.md` と
`human_eval/output/report.md` を参照。既存20曲の結果とは別保存で、共有Embeddingに軽量headを追加した。
Vocal/Instrumentalの誤判定が残るため、現時点では559曲へ拡大しない。
2026-08-29のVocal/Instrumental追加15曲・前回11曲回帰は `vi_eval/README.md` と
`vi_eval/output/report.md` を参照。一般Vocal 5/5、Instrumental 8/9（電子系BGMのHard Case含む）。
新たな結果に基づく推奨は「559曲の評価へ進む」で、本番採用ではなく、全曲処理は未実施。
公式native Essentiaとのfrontend比較も実施した。初回調査の「Mac wheelなし」は不正確で、
2.1b6.dev1389にはCPython 3.12/macOS arm64 wheelが存在する。検証専用領域だけへ導入した。
以下は初回20曲PoCの構成・手順（上記の追記を優先）。

## 安全境界

- v1の `audio.py`、CLI、requirements、SQLite、出力JSONは変更しない。
- `analyzer/cache/analysis.sqlite3` は `mode=ro&immutable=1` で読む。v1のCacheクラスは生成しない。
- 本番SQLiteとルートの `music_features.json` のSHA-256を選曲前後・実行前後に照合。WAL/journal存在時は停止。
- 選曲は保存済み559件のmetadataのみ。音楽Rootの再帰検索・全曲走査をしない。
- 最初に10〜30曲のmanifestを固定し、以後の自動拡大を禁止。既定の選択は20曲。
- 実音源はmanifestにある曲だけ。size/mtimeがv1から変化、root外へ出るパス、未ダウンロードiCloudファイルは拒否。
- 成功結果は1曲単位で別SQLiteへcommit。Ctrl+C/SIGTERMで完了曲を維持。SIGKILLでも完了transactionは残る。
- 成功済みは常にSkip、失敗・未完了曲だけ再試行。全Cache-hit時はモデルをロードせず音源にも触れない。
- `data/` `models/` `output/` `.venv/` `.runtime/` はPoC専用・Git対象外。出力先の外部指定は受け付けない。
- iPhone側コード、schemaVersion、Badge閾値、Selection Engine、Playbackは変更しない。
- ダウンロード後はローカル推論。ONNX Runtimeは**import前**に `ORT_DISABLE_TELEMETRY=1` を設定。
  APIの `disable_telemetry_events()` だけでは初期化イベントに間に合わないため、両方設定する。
  [公式テレメトリ設定](https://github.com/microsoft/onnxruntime/blob/main/docs/Privacy.md)

## 現在のv1と役割分担

v1は `analysisVersion=1` / `dsp-beta1-r2`。22,050Hz、最大3×30秒の音響指標を中央値で集約し、
Piano・Mood・Genre・Voiceを固定加重式で合成していた。SQLiteには最終スコアと照合情報が残るが、中間DSP指標は残らない。

|分類|v2での扱い|
|---|---|
|DSP: tempo, RMS loudness proxy, onset, bass, spectral, harmonic/percussive|v1の `_analyze_segment` を再利用。デコード後の一時波形にのみ適用|
|DSP: energy|`clip(.55*loudness + .25*onset + .20*percussive, 0, 1)` を維持。意味分類には使わない|
|意味: piano, ambient, electronic, DnB, calm, dark, vocal|学習済みモデルの該当ラベル。DSP値から補完しない|
|意味: bright, aggressive, instrumental|今回の構成に直接対応するラベルがないので未出力|

既存DSPのloudnessはRMS由来の0〜1指標でLUFSではない。
診断用に別途 `20*log10(RMS)` のdBFSも保存するが、正式schemaにない `features.loudness` は出力しない。
`dark=.72*(1-bright)+.28*bass`、`instrumental=1-vocal` などのv1意味分類式は呼び出さない。

## モデル調査と選定

調査日: 2026-08-27。推論時間は採用構成だけ実測。非採用候補のMac速度は未測定であり、推定精度のランキングではない。

|候補|Python / Apple Siliconの実行経路|分類範囲・score|サイズ/運用上の判断|
|---|---|---|---|
|musicnn MTT/MSD|公式Python実装はTensorFlow、`numpy<1.17` 制約あり|音楽タグ、piano、vocal系等|旧依存環境の整合が必要。現行3.12環境への安定導入を優先し不採用。重みサイズ/速度未測定|
|Essentia + TensorFlow各分類器|EssentiaのmacOS導入はHomebrew/ソースビルド経路。今回のPyPIリリースにはMac wheelなし|多様なinstrument/genre/mood、sigmoid等|ライブラリ全体やTensorFlowを導入せず、公開ONNXモデルを利用する方針|
|**Discogs-EffNet + Jamendo heads**|**ONNX Runtime CPUのnative arm64 wheelを実機確認**|400 styles + 汎用50tags + Mood56。すべて0〜1のモデル出力|**採用。18.03MB + 2.73MB + 2.74MB = 23.49MB**。重いbackboneは1回、2つの小headで共有|
|MAEST (MTG)|ONNX公開あり、Transformer系|400/519 styles、下流分類head|有力な次候補。ただし今回の最小構成では軽量CNNを先に実測。サイズ/速度未測定|
|PaSST / hear21passt|PyTorchによるローカルPython推論|AudioSet等のイベント分類、OpenMIC楽器への応用|音楽専用Mood/細分Genreとの対応・追加環境が必要。サイズ/Apple Silicon速度未測定|

一次資料:

- [musicnn本体](https://github.com/jordipons/musicnn)、[依存定義](https://github.com/jordipons/musicnn/blob/master/setup.py)
- [Essentia導入](https://essentia.upf.edu/installing.html)、[PyPI配布](https://pypi.org/project/essentia/)
- [モデル一覧・EffNet/MAEST](https://essentia.upf.edu/models.html)、[EffNet重み配布](https://essentia.upf.edu/models/music-style-classification/discogs-effnet/)
- [MTG-Jamendoデータセット](https://github.com/MTG/mtg-jamendo-dataset)
- [PaSST公式実装](https://github.com/kkoutini/PaSST)
- [ONNX Runtime導入](https://onnxruntime.ai/docs/install/)

### 採用モデル

1. `discogs-effnet-bsdynamic-1.onnx`: 16kHzのmel patchから400 style確率と1280次元embeddingを出力。
2. `mtg_jamendo_top50tags-discogs-effnet-1.onnx`: 同じembeddingからGenre/Instrument/Moodの50タグ。
3. `mtg_jamendo_moodtheme-discogs-effnet-1.onnx`: 同じembeddingから56のMood/Theme。

汎用タグだけではDark/Calmがないため、Mood headを1つ補助として追加。
独立した重いモデルを多数走らせるensembleではない。embeddingはheadへの一時入力だけで保存・exportしない。
汎用タグには piano, voice, acousticguitar, electricguitar, strings, violin, synthesizer,
ambient, electronic, classical, jazz, rock, metal, pop, relaxing 等がある。
Moodには calm, dark, melancholic, relaxing, happy, energetic, uplifting 等がある。
モデルのラベルは `models/*.json` のclassesを使い、ONNXの実出力次元と照合する。

注意: top50の配布metadataには出力shapeを56とする不整合がある。classesは50、**ONNXの実出力も50**であることを確認済み。
embeddingモデルはmetadata内 `inference.embedding_model` に指定されたDiscogs-EffNetを使用。

### MyMusicへのmapping

|MyMusic|モデルのラベル|変換|
|---|---|---|
|piano|top50 `piano`|直接|
|ambient|top50 `ambient`|直接|
|electronic|top50 `electronic`|直接|
|drumAndBass|Discogs `Electronic---Drum n Bass`|直接|
|calm|Mood `calm`|直接。relaxing等を足さない|
|dark|Mood `dark`|直接。低域やbrightの逆数は使わない|
|vocal|top50 `voice`|直接。歌唱以外の声を含む可能性に注意|
|bright|なし|未出力。happy/upliftingを「明るさ」と同一視しない|
|aggressive|なし|未出力。energetic/heavy/actionを攻撃性と同一視しない|
|instrumental|なし|未出力。`instrumentalpop` はジャンルであり、`1-voice` も採用しない|

各patchの**モデル内sigmoid出力**を全patchで算術平均し、小数6桁に丸める。
追加sigmoid、強制clamp、曲集合内min-max正規化、Badge用の引き上げはしない。不正な値はエラーにする。
モデルの確率は未校正のタグscore。分類器を跨ぐ確率の直接比較・共通閾値には限界がある。
上位5ラベルは汎用50タグ内で順位付けし、MoodとDiscogsの上位は別記する。

ラベル根拠:
[汎用50タグ](https://essentia.upf.edu/models/classification-heads/mtg_jamendo_top50tags/mtg_jamendo_top50tags-discogs-effnet-1.json)、
[Mood56](https://essentia.upf.edu/models/classification-heads/mtg_jamendo_moodtheme/mtg_jamendo_moodtheme-discogs-effnet-1.json)、
[Discogs400](https://essentia.upf.edu/models/music-style-classification/discogs-effnet/discogs-effnet-bsdynamic-1.json)

### モデル入力

Essentiaの公開パラメータに合わせてNumPy/librosaでfrontendを独立実装した。
16kHz mono、512点の対称Hann（振幅正規化なし）、hop256、ゼロ中心の先頭frame、96 Slaney mel帯域、
0–8000Hz、linear三角重み、unit-triangle-area正規化、power spectrum、`log10(1+10000*melPower)`。
128frame/patch、hop62。末尾の不完全patchは捨てる。少なくとも2.048秒必要。
推論batchは最大8、CPU内部thread2、曲は常に逐次。

ゼロ信号と1kHz合成信号に対し、別のlibrosa STFT構成との数値一致をunit testで確認。
ただしnative Essentiaとの数値パリティ試験は未実施。Mac用Essentiaを追加ビルドせずPoCを完結させたため、
正式昇格前には同じ合成波形でnative frontendと照合すること。

パラメータ根拠:
[MusiCNN frontend](https://github.com/MTG/essentia/blob/master/src/algorithms/spectral/tensorflowinputmusicnn.cpp)、
[Windowing](https://github.com/MTG/essentia/blob/master/src/algorithms/standard/windowing.h)、
[三角帯域正規化](https://github.com/MTG/essentia/blob/master/src/algorithms/spectral/triangularbands.cpp)、
[EffNet patch設定](https://essentia.upf.edu/reference/streaming_TensorflowPredictEffnetDiscogs.html)

## セットアップと実行

Apple Silicon / macOS 14以降 / CPython 3.12。実測はM1 Max、32GiB、macOS 26.6.2、Python 3.12.11。
FFmpegがPATHに必要（今回既存の `/opt/homebrew/bin/ffmpeg` を使用）。グローバルPythonやv1環境は変更しない。
以下はリポジトリルートから実行する。

```sh
/opt/homebrew/opt/python@3.12/bin/python3.12 -m venv analyzer/poc/.venv
analyzer/poc/.venv/bin/python -m pip install -r analyzer/poc/requirements-lock.txt
analyzer/poc/.venv/bin/python -B analyzer/poc/prepare_models.py

# metadataのみで20曲を固定。既存selectionがあれば上書きせず停止。
analyzer/poc/.venv/bin/python -B analyzer/poc/run.py --select 20

# 初回は2曲だけ完了させ、checkpointを確認可能。
analyzer/poc/.venv/bin/python -B analyzer/poc/run.py --limit 2

# 同じ固定20曲の残りだけ。Ctrl+C後も同じコマンド。
analyzer/poc/.venv/bin/python -B analyzer/poc/run.py --resume

# 再推論せず保存済み結果だけからレポートを再生成。
analyzer/poc/.venv/bin/python -B analyzer/poc/run.py --report-only

# 実音源を使わないunit tests。
cd analyzer/poc
.venv/bin/python -B -m unittest -v test_poc
```

`--limit` はこの実行で試行する未完了曲数（1〜30）で、出力済み曲を削らない。
初回selection以降の自動選び直しは不可。559曲/20,000曲用のオプションは存在しない。
20曲にはピアノ独奏、弦楽器、Piano+Vocal、Electronic系、Rock系、Vocaloid等のmetadata候補と、
v1 score両端の曲を含めた。候補名は正解ラベルではなく、既存559曲自体も母集団を代表しない。
明示的にAmbient/DnBと確認できた正例が足りない点は評価時に区別する。

## 保存・出力

```text
poc/
  run.py / engine.py / storage.py / reporting.py
  prepare_models.py / test_poc.py
  requirements.txt / requirements-lock.txt
  models/                  # 3 ONNX + 各metadata + SHA-256 manifest
  data/selection.json      # 固定曲リスト・v1比較値・本番checksum
  data/poc.sqlite3         # v2のみ。生ラベル・DSP診断・timing・RSS
  data/runs.json           # 部分実行・resumeの実測履歴
  output/music_features_v2_poc.json
  output/comparison.json   # 全曲の新旧比較・全モデルラベル
  output/summary.json      # 分布・ヒストグラム・性能
  output/report.md         # 人間向け全曲比較・上位5ラベル
```

Cache keyはroot/relativePath/size/mtimeと、model checksum・frontend・mapping・analysisVersionを含む設定。
将来モデル/計算を変える際はREVISIONも更新する。このPoCから本番cacheへの移行は行わない。

出力は**既存schemaVersion 1のままanalysisVersion 2**。未知のフィールドは追加しない。
relativePathは既存v1のNFC正規化・POSIX相対パスをそのまま複製し、size/duration/title/artist/album/
modificationDateも保存済みの同一値を継承する。既存schema validatorで検証してからatomic exportする。
`loudness`、モデル詳細、timing、embeddingはImport JSONに含めない。

```json
{
  "schemaVersion": 1,
  "analysisVersion": 2,
  "generatedAt": "2026-08-27T15:00:00Z",
  "tracks": [{
    "relativePath": "Artist/Song.m4a",
    "fileSize": 123456,
    "duration": 243.21,
    "title": "Song",
    "artist": "Artist",
    "album": "Album",
    "features": {
      "piano": 0.86, "ambient": 0.06, "electronic": 0.02,
      "drumAndBass": 0.0005, "calm": 0.02, "dark": 0.02,
      "vocal": 0.01, "energy": 0.34, "tempo": 129.2
    }
  }]
}
```

これはschema説明用の例であり、上記数値は検証用の正解ではない。
生成JSONはImport可能な構造だが**今回iPhoneへImportしない**。v2はv1より新しいため、Importすると対象曲の特徴量を更新する。

## 性能・限界・次段階

1曲の90秒上限はv1と同じ相対位置（利用可能長の10%/50%/90%）。短曲は既存offset計算に従う。
FFmpegで1区間ずつ元sample rate/channel数のfloat32 PCMをデコードし、channel算術平均→librosa/soxr_hqで22,050Hz化する
（解析用の一時PCMのみ。原音源へは書き込まない）。`-ac 1` の既定mixは平均方式と約3dB異なるため使用しない。
最初の20曲試行でこの差を合成信号により確認し、同じ20曲だけを修正条件で再測定した。旧試行は `data/initial-equal-power-report/` に残す。
DSP後に16kHzへresampleし、mel化→CNN→2head→確率平均。波形は毎区間解放し、曲のスコアだけ保存。
RMS/duration/genreの小値と欠損は異なる。未対応特徴は0ではなくフィールド欠損。

性能報告はdecode（FFmpeg起動/seek/resample含む）、DSP、model preprocess、ONNX inference、合計を分離。
初回setupと初回のdecode遅延は別途注意し、全曲への線形推定は保証値にしない。
peak RSSはPythonのOS high-water markでFFmpeg子プロセスを含まない。20曲の傾向だけでは長期リーク不存在は証明できない。
将来の2万曲対応ではiCloudの事前ダウンロード、電源・発熱、failure再試行、metadata差異、モデルライセンス、
評価済みラベルのprecisionを先に確認する。並列化、GUI、embedding export、全曲hashはこのPoCの範囲外。

モデルは [MTGのCC BY-NC-SA 4.0](https://essentia.upf.edu/models.html)（別途商用ライセンスの提供あり）。
個人の非商用PoCとして取得し、重みはGitに同梱しない。配布・商用利用への昇格時はライセンス条件の確認が必要。
モデル著者: Pablo Alonso-Jiménez, Xavier Serra, Dmitry Bogdanov / Music Technology Group, UPF。
主要論文: *Music Representation Learning Based on Editorial Metadata from Discogs*, ISMIR 2022。
