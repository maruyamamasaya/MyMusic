# MyMusic Semantic v2 — 通常運用

本番DSP Analyzerとは独立した`semantic.py`。音楽Rootを毎回再帰走査し、新規・更新Trackだけ
Discogs-EffNet Embeddingを生成する。既存Embeddingはchecksumまで確認して再利用し、現在の
Semantic headを適用してMyMusic互換JSONをatomic更新する。

**本番`cache/analysis.sqlite3`、リポジトリルートの`music_features.json`、既存PoCデータは変更しない。**

Semantic headの分布はインスト／OST中心3,837曲、従来3,552曲、追加ボーカル中心441曲で評価済み。
作品依存の補正やglobal calibrationは追加せず、raw head、mapping、patch mean集約をSemantic v2としてFIXした。
根拠と既知制約は[`SEMANTIC_CALIBRATION_REPORT.md`](SEMANTIC_CALIBRATION_REPORT.md)を参照。

## 通常運用コマンド

リポジトリルートから、今後は次の1コマンドだけを実行する。

```sh
analyzer/poc/.venv/bin/python -B analyzer/semantic.py --update
```

`semantic_cache/scope.json`に保存済みの音楽Rootを使い、次を順番に行う。

1. Root以下を再帰走査し、新しいArtist／Albumフォルダを含む対応音源を列挙する。
2. NFC正規化した`relativePath`で既存identityと照合する。
3. `fileSize + mtimeNS`が同じTrackはmetadata読取とEmbedding生成をSkipする。
4. 新規Trackと更新Trackだけmetadataを読み、Embeddingを生成する。
5. 同じEmbedding/head profileの分類はSkipし、新規・更新分だけheadを適用する。
6. `semantic_cache/output/music_features_semantic_v2.json`をatomic更新する。

## 全ライブラリのアプリ用JSONを統合

各libraryの解析cache、Embedding、SQLiteは分離したまま、完了済みの最終JSONだけを統合する。

```sh
analyzer/poc/.venv/bin/python -B analyzer/semantic.py --export-all
```

自動検出対象は次の直下だけ。

- `analyzer/semantic_cache/output/music_features_semantic_v2.json`
- `analyzer/semantic_workspaces/library-*/output/music_features_semantic_v2.json`

アプリへimportする統合結果は
`analyzer/output/music_features_semantic_v2_merged.json`。
schemaVersion 1 / analysisVersion 2のままで、各TrackのmetadataとSemantic特徴量を変更せずコピーする。
source情報は既存MyMusic schemaへ追加できないため、アプリ用JSONには含めず、同じ出力directoryの
`music_features_semantic_v2_merged.sources.json`へ`libraryId`、source、output indexを保存する。

空またはまだ出力のないworkspaceは理由を表示してSkipする。JSON破損、schema不一致、Semantic特徴量不足、
同一music-rootの重複cache、library内のrelativePath重複はfatal errorとし、前回のアプリ用JSONを置き換えない。
sourceごとの件数、入力合計、出力件数、異なるlibrary間のrelativePath衝突数を表示する。
workspaceが更新中の場合も、atomicに確定済みの直前JSONだけを読み、更新中であることを表示する。

異なるmusic-rootの同じrelativePathは別Trackとして両方保持する。単純なrelativePath dedupeは行わない。
同一library内ではrelativePathがworkspace identityなので重複を拒否する。同一内容・同一relativePathの音源が
複数rootに複製されている場合、schema v1だけではiPhone import時にrootを区別できずAmbiguousになり得る。
source manifestはこの診断情報を失わないためのsidecarであり、MyMusic import schemaは変更しない。

`--update`と`--export-all`は意図的に分離している。別workspaceの破損によって正常な差分解析まで失敗扱いにせず、
解析結果を確認してからアプリ用JSONを明示的に更新するためである。統合処理は音源、Embedding、SQLite、headを
読み書きせず、`audioReads=0` / `decodeCalls=0`。

既存の3,552曲固定scopeは初回`--update`時に同じcache内で動的scopeへ移行する。
追加曲は本番DSP JSONへ追記せず、Semantic出力だけへ追加される。削除曲はSQLite行やNPZを
破壊せず`present=0`として記録し、出力から安全に除外する。同じidentityで再追加された場合は
保存済みEmbeddingを再利用できる。

head profileが変わった場合はEmbeddingを維持したまま全対象のheadを再評価する。
この処理は音源、ffmpeg/ffprobe、backboneを使わず`audioReads=0` / `decodeCalls=0`となる。
同じprofileとEmbedding checksumの組合せはSkipする。

### 別の音楽フォルダだけを独立解析

`--update` と `--music-root` を同時指定すると、既存baseline JSONを対象リストに使わず、
指定Rootだけを走査してEmbedding、head、JSON出力まで1回で行う。

```sh
analyzer/poc/.venv/bin/python -B analyzer/semantic.py \
  --update --music-root "/absolute/path/to/new/music-folder"
```

保存先はRootの絶対パスから一意に決まる
`analyzer/semantic_workspaces/library-<ID>/`。同じコマンドの再実行は完了曲をSkipし、
新規・更新・削除曲だけを反映する。既存の `analyzer/semantic_cache/`、その出力JSON、
本番SQLite、本番JSONには書き込まない。

## 実行環境

既存PoCのPython 3.12 venv・依存・検証済みONNXを読み取り専用で再利用する。
新モデルの取得や既存venvへの依存追加はない。FFmpeg/ffprobeがPATHに必要。
Apple Silicon、逐次1曲、推論batch最大8、内部thread2。

### 出力

既定出力:

```text
analyzer/semantic_cache/output/music_features_semantic_v2.json
```

`--update --music-root` の場合は、対応する
`analyzer/semantic_workspaces/library-<ID>/output/music_features_semantic_v2.json` が既定出力。

`--export-all`は各workspaceの上記JSONを入力にし、
`analyzer/output/music_features_semantic_v2_merged.json`だけをアプリ用に生成する。

既存schemaそのまま、`schemaVersion: 1` / `analysisVersion: 2`。
既存Trackの照合metadataとDSP値はbaselineから保持する。新規Trackと更新Trackは現在の音源metadataを
保存し、古いDSP値を引き継がない。成功したEmbedding＋現在のhead profileの結果だけを出力する。
本番JSON・本番SQLite・PoCへの出力指定は拒否し、このCLI自身の出力だけをatomic replaceする。

## 保存構成

```text
analyzer/semantic_cache/
  owner.json                    # 専用cacheであることの識別
  run.lock                      # 複数プロセスの同時更新を防止
  scope.json                    # 現在存在するTrack metadataとRoot
  embedding-profile.json        # backbone/frontendの独立したsignature
  index.sqlite3                 # Track索引・状態・head結果・実行履歴
  embeddings/<profile>/<shard>/<identity>.npz
  head-profiles/<profile>.json   # head/mapping/version/checksum
  last-update-run.json          # scan/embed/heads/audioReadsの直近summary
  output/music_features_semantic_v2.json
  .runtime/                     # ライブラリが作るcacheもここに隔離
```

SQLiteは`relativePath`主キーで1曲1行。`present`で現在の存在状態を管理し、削除時にも行を消さない。
`source_features_json`はbaseline DSP値を保持し、更新Trackでは空にしてstale値の継承を防ぐ。
音源全体をメモリへ保持しない。
Embeddingは1曲ごとのNPZ。ファイルはhashで分散配置し、20,000曲で1ディレクトリに集中させない。
JSON export時に全曲の小さなmetadata/feature辞書をまとめるが、全曲の波形/Embeddingを一括ロードしない。
`--cache-dir` は `analyzer/semantic_cache` または `analyzer/semantic_workspaces` の配下のみ。
別データセットは明示的な別cacheで扱う。
symlink/hardlink、未所有の非空ディレクトリへの書き込みを拒否する。

### NPZ仕様

|key|内容|
|---|---|
|embeddings|float32 `[N, 1280]`。通常3×30秒、各29patchで `[87, 1280]`。PoCと同じ入力/モデル|
|segment_offsets|各解析区間の開始秒|
|segment_patch_counts|各区間のpatch数。配列の区間境界を復元できる|
|discogs_mean|backboneが出す400style確率の全patch平均。DnB等に使う|
|metadata_json|形式version、Root、identity、mtimeNS、Embedding profile、生成/移行情報|

元のPoCの `npz['embeddings']` と互換。新しい項目は付随情報。
許可するパッチ数は最大256、展開後サイズにも上限を設け、破損/不正なアーカイブを拒否する。
2.048秒未満など有効patchを作れない曲はエラー記録し、次へ進む。

現行のPoC frontendをそのまま利用。前回発見した末尾frameの修正候補は今回昇格しない。
通常30秒では使用patchに違いがなく、保存済みPoCとの互換性を優先した。

### 既存26曲の再利用

初回生成前にPoCの11曲＋15曲の保存結果を読み取り専用で参照する。
Root、relativePath、fileSize、duration、modificationDate、mtimeNS、metadata、モデル/frontend設定、NPZ checksumが一致した場合だけコピーする。
元PoCのSQLiteはimmutable read-only、JSON/NPZも読み取り専用。移行先には新形式の独立コピーを作る。
コピー時は `reusedPoC` が増え、音源を再解析しない。
互換性を確認できない場合は新規生成する。既存NPZの破損時はエラーにし、勝手に修復しない。

## Track identity

既存Analyzerの `discover_audio_files()` / `relative_path()` を再利用。
Rootからの相対化、POSIX区切り、Unicode NFC、case保持を一致させる。
曲名だけでの照合/fuzzy matchingはない。Unicode正規化後のパスが重複すればAmbiguousとして除外。
既存TrackはfileSizeとmtimeNS、移行前の未解析TrackだけはfileSizeと秒mtimeを照合する。
新規・更新Trackは音源からduration/title/artist/albumを読み直す。Embedding保存後にもmtimeNSを再確認し、
処理中にファイルが変わった場合はcommitしない。古いidentityへ新しいEmbeddingを紐付けない。
Root以下の新しいサブフォルダも毎回の走査対象となる。
NPZ checksumは**音源contentHashではない**。全曲音源SHA-256計算は行わない。

## 特徴量とモデル

|MyMusic feature|取得元|
|---|---|
|vocal / instrumental|既存voice_instrumental headの2クラスsoftmax|
|aggressive|既存mood_aggressive head|
|calm|既存mood_relaxed headのrelaxed|
|piano / electronic / ambient|既存Jamendo top50 head|
|dark|既存Jamendo mood/theme headのdark|
|drumAndBass|保存済みDiscogs `Electronic---Drum n Bass`|
|energy / tempo|未更新の既存identityだけ、本番baseline JSONに保存済みのDSP値をコピー|

意味スコアはpatchごとのモデル出力を平均。係数調整/再sigmoid/Artist例外/Badge閾値変更はない。
新規・更新TrackのEnergy/Tempoは未出力とし、Embeddingから捏造しない。本番DSP解析も起動しない。
Bright、loudness、embedding自体はMyMusic Import JSONへ追加しない。
モデルは従来どおりCC BY-NC-SA。今回も配布や商用利用を新たに許可するものではない。

## Resume / 失敗 / 中断

- 完了Embeddingは再実行でchecksum確認してSkip。head更新で無効化されない。
- NPZは一時ファイルへ保存→fsync→atomic replace→SQLite commitの順。
- NPZ保存後/DB commit前の中断は、次回NPZのmetadataを検証して `recovered` として回復。音源再解析なし。
- Ctrl+C/SIGTERMでは完了分を保持し、出力更新前に停止する。次回同じ`--update`で再開する。
- 失敗はSQLiteにerrorを記録して次へ進む。`state='error'` が再試行対象。
- 破損NPZ・identity不一致は自動上書きせずエラー。成功済み曲を再解析するforceオプションはない。
- 全曲成功は終了コード0、曲別失敗ありは1、設定/環境エラーは2、中断は130。
- 同じcacheの処理を同時に動かすことは拒否する。

## 検証

疑似ライブラリで既存3曲、新規1曲、新しいArtist/Albumサブフォルダ内の新規1曲を使用した。

- 初回update: 既存3曲Skip、新規2曲だけEmbedding生成、`audioReads=2`
- 再update: 5曲すべてEmbedding/head Skip、`audioReads=0`
- heads強制再評価: 5曲成功、音源stat・backbone・subprocessなし、`audioReads=0`
- ファイル更新: 更新1曲だけ再Embedding、他2曲Skip
- ファイル削除: SQLite行は保持して`present=0`、Semantic JSONから除外
- MyMusic schema validation、新規サブフォルダ検出、Unicode衝突、Ctrl+C後のNPZ回復、破損拒否を確認
- 20,000件のscopeを2回reconcileし、初回insertと再実行全Skipを確認

1曲ごとのEmbeddingは分散ディレクトリへ保存し、SQLite照合と処理は線形で、波形やEmbeddingを
全曲分メモリへ保持しない。20,000曲向けの構造とするが、20,000実音源での長時間実測は未実施。
既存実測の平均約415KB/曲ならNPZだけで約8.3GBの目安となるため、空き容量を別途確保する。
本番JSON/SQLiteとPoCへの書込経路はない。
Swift変更はないためXcode Build対象外。
