# MyMusic Mac Feature Analyzer — Beta 1

Mac上の音楽Rootを再帰的に解析し、MyMusicの`Track Feature schemaVersion: 1`と互換性のある
`music_features.json`を生成するCLIです。iPhone上では音響解析しません。

## 採用方針

- 音響解析: [librosa 0.11](https://librosa.org/doc/0.11.0/index.html)
- metadata / duration: [Mutagen](https://mutagen.readthedocs.io/en/latest/)
- decode: SoundFileを優先し、未対応codecはlibrosa 0.11のaudioread fallbackとFFmpegを利用
- cache: Python標準のSQLite
- 分類方式: 複数の音響特徴を重み付けする、決定論的な`DSP Beta v1`スコアモデル

EssentiaのDiscogs-EffNetと分類headも検討しました。モデル自体にはmood、voice/instrumental、
instrument等の適切な分類器がありますが、Essentia公式のmacOS ARM TensorFlow環境はHomebrew buildと
追加依存が必要で、現時点では導入失敗の報告も残っています。約2万曲の標準Beta環境には
セットアップの再現性を優先し、学習済みモデルは採用していません。

したがって、`piano`や`vocal`等は学習済み分類器の確率ではありません。BPMだけから推測せず、
HPSS、chroma、スペクトル、onset等を組み合わせた連続スコアですが、検索・Weighted Random用の
Beta補助値として扱ってください。

参考:

- [librosa feature extraction](https://librosa.org/doc/0.11.0/feature.html)
- [librosa advanced I/O](https://librosa.org/doc/0.11.0/ioformats.html)
- [Essentia music auto-tagging tutorial](https://essentia.upf.edu/tutorial_tensorflow_auto-tagging_classification_embeddings.html)
- [Essentia model catalog](https://essentia.upf.edu/models/)

## 1. Python環境準備（Apple Silicon）

HomebrewのPython 3.11または3.12を推奨します。AAC、ALAC、M4A等のfallback decode用にFFmpegも
インストールします。

```bash
brew install python@3.12 ffmpeg
cd /path/to/MyMusic/analyzer
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Python 3.10でも動作します。macOS付属Pythonではなく、Homebrew Pythonの利用を推奨します。
pyenv等で作成したPythonに`_lzma`などの標準moduleが欠けている場合、Analyzerは起動時に環境エラーを
表示します。その場合もHomebrew Pythonでvenvを作り直してください。

## 2. 少数曲テスト

MyMusicで登録している音楽フォルダと同じRootを指定してください。`--limit`はcache済みSkipを除く、
この実行で新たに解析する最大曲数です。

```bash
python analyze.py "/path/to/Music" --limit 10 --resume
```

50曲で確認する場合:

```bash
python analyze.py "/path/to/Music" --limit 50 --resume
```

既定出力:

```text
analyzer/output/music_features.json
```

既定cache:

```text
analyzer/cache/analysis.sqlite3
```

## 3. 再開と全曲解析

同じコマンドを再実行すると、file size、nanosecond mtime、analysisVersion、解析設定が一致する
成功済みTrackをSQLite cacheからSkipします。`--resume`は既定動作ですが、意図を明確にするため
コマンド例では明示しています。

```bash
python analyze.py "/path/to/Music" --resume
```

Ctrl+Cを押すと、処理中の1曲を完了してから停止し、その時点の有効なcacheでJSONを書き出します。
再度同じコマンドを実行すれば続きから再開できます。壊れた音源やdecodeできない音源はFailedとして
cacheへ記録し、バッチ全体は続行します。Failed曲は次回実行時に再試行されます。

cacheを無視して再解析する場合:

```bash
python analyze.py "/path/to/Music" --force --limit 50
```

出力先を変える場合:

```bash
python analyze.py "/path/to/Music" --resume --output "/path/to/music_features.json"
```

## 4. 対応形式とmetadata

MyMusicと同じ拡張子だけを対象にします。

```text
m4a, mp3, flac, wav, aiff, aif, aac
```

出力する照合情報:

- `relativePath`: 指定した音楽Rootを`Path.resolve()`した位置からの相対パス。Swift側の
  `StableTrackIdentifier.relativePath`と同じく、componentを`/`で連結しUnicode NFC
  （Swiftの`precomposedStringWithCanonicalMapping`相当）へ正規化。
- `fileSize`: byte単位。
- `duration`: Mutagenが取得した秒数。
- `modificationDate`: RFC 3339 UTC。
- `title`, `artist`, `album`: 埋込みtag。欠落時はMyMusicに合わせ、ファイル名／folder構造／Unknown値で補完。

`relativePath`はURL encode、case folding、先頭`./`付与を行いません。AnalyzerにはMyMusicで登録した
folderと同じMusic Rootを指定してください。異なる上位folderを指定すると文字列が変わり、Fallback照合へ
回るため安全性と照合率が低下します。

`contentHash`はschema上の予約項目ですが、Beta 1では出力しません。全曲をSHA-256のためだけに
読み直す処理も行いません。

## 5. 特徴量の算出

既定では曲の10%、50%、90%付近から各30秒、最大3区間を1区間ずつdecodeします。音源全体や
複数曲をMemoryへ保持しません。区間ごとの値を中央値で集約し、解析後に配列を解放します。

| 出力 | 主な音響情報 |
|---|---|
| `tempo` | onset envelopeに対するlibrosa tempo推定の区間中央値 |
| `energy` | RMS由来loudness、onset強度、percussive energy |
| `piano` | harmonic energy、chroma集中度、適度なtransient、spectral contrast、mid-band |
| `ambient` | harmonic優勢、低onset、低pulse、低energy、低ZCR |
| `electronic` | percussive/bass energy、spectral flatness、pulse clarity、brightness |
| `drumAndBass` | 172 BPMおよびhalf-time 86 BPM近傍、electronic、percussive、bass、pulse |
| `aggressive` | energy、loudness、onset、brightness、percussive energy |
| `calm` | 低aggressive、harmonic、低onset、低energy、ambient |
| `bright` | spectral centroid、rolloff、高域energy |
| `dark` | brightnessの低さ＋低域energy |
| `vocal` | harmonic、voice帯域、spectral contrast、dynamic range、低flatness |
| `instrumental` | `1 - vocal` |

カテゴリ値はすべて`0.0...1.0`へclipします。RMS由来loudnessは`energy`と`aggressive`の内部計算に
利用しますが、MyMusic schema v1の標準feature fieldではないためJSONへは出力しません。

主要な派生スコアは、正規化済み音響特徴の次の重み付き和を`0...1`へclipしたものです。

```text
piano = 0.28 harmonic
      + 0.24 chromaConcentration
      + 0.20 transientBalance
      + 0.16 spectralContrast
      + 0.12 midBand
      - 0.10 spectralFlatness

ambient = 0.24 harmonic
        + 0.23 (1 - onset)
        + 0.20 (1 - pulse)
        + 0.18 (1 - energy)
        + 0.15 (1 - ZCR)

drumAndBass = 0.32 tempoAffinity(172 BPM / half-time 86 BPM)
            + 0.20 electronic
            + 0.18 percussive
            + 0.16 bassBand
            + 0.14 pulse

aggressive = 0.28 energy
           + 0.22 internalRMSLoudness
           + 0.18 onset
           + 0.17 brightness
           + 0.15 percussive

calm = 0.30 (1 - aggressive)
     + 0.22 harmonic
     + 0.18 (1 - onset)
     + 0.15 (1 - energy)
     + 0.15 ambient
```

これらは学習済みモデルが直接出力する確率ではありません。解析revisionはcache keyにも含まれ、
式や出力contract変更時に古いcacheを再利用しません。

解析量を減らす例:

```bash
python analyze.py "/path/to/Music" --resume --segment-seconds 15 --segments 2
```

segment設定はcache keyに含まれます。設定を変えると、同じ曲も別解析設定として再解析されます。

## 6. 出力JSON

出力はリポジトリの
[`Documentation/track-feature-schema-v1.json`](../Documentation/track-feature-schema-v1.json)を正とし、
書出し直前にAnalyzer側でも同じ必須field、許容field、値域、日時、相対パスを検証します。

```json
{
  "schemaVersion": 1,
  "analysisVersion": 1,
  "generatedAt": "2026-08-27T12:34:56Z",
  "tracks": [
    {
      "relativePath": "Artist/Album/01 - Song.flac",
      "fileSize": 12345678,
      "duration": 243.21,
      "modificationDate": "2026-08-20T03:12:45Z",
      "title": "Song",
      "artist": "Artist",
      "album": "Album",
      "features": {
        "tempo": 92.4,
        "energy": 0.72,
        "piano": 0.15,
        "ambient": 0.18,
        "electronic": 0.64,
        "drumAndBass": 0.81,
        "aggressive": 0.22,
        "calm": 0.58,
        "bright": 0.61,
        "dark": 0.27,
        "vocal": 0.12,
        "instrumental": 0.88
      }
    }
  ]
}
```

## 7. iPhoneへ転送してImport

1. `output/music_features.json`をAirDrop、iCloud Drive、Finder等でiPhoneへ転送。
2. MyMusicの「設定」を開く。
3. 「Beta機能」→「音楽特徴量」を開く。
4. 「特徴量JSONを読み込む」を押す。
5. FilesからJSONを選択。
6. 照合成功、未照合、曖昧の件数を確認。

## 8. 2万曲実行時の注意

- 最初に`--limit 10`、次に`--limit 50`でdecode可能形式とscore傾向を確認してください。
- 既定では1曲最大約90秒をdecodeします。所要時間はcodec、曲長、Mac、保存先によって大きく変わるため、
  50曲の実測から全体時間を見積もってください。
- ネットワークdriveやiCloud未download音源ではI/O失敗やdownloadが発生し得ます。可能ならlocal保存を使います。
- sleepやdisk取り外しを避け、数千曲単位で出力JSONとSQLite cacheをbackupしてください。
- 並列処理は実装していません。Memoryとthermal安定性を優先して常に1曲ずつ処理します。
- JSON生成時は全成功entryをMemoryへ載せますが、音声bufferは1区間だけです。2万entryのJSONは音声と比べて小さい量です。
- `analysisVersion`は解析モデル・定義を本当に変更したときだけ上げてください。新しいversionはMyMusic側で特徴量を更新します。

## 9. 将来拡張

音響backend、cache key、schema生成を分離しているため、Essentia/ONNX分類器、contentHash、genre、
embedding、制御付き並列処理、Mac GUIを追加できます。EmbeddingはBeta 1では生成しません。

## 10. 開発者向け確認

軽量Unit Test:

```bash
cd /path/to/MyMusic
PYTHONPATH=analyzer python -m unittest discover -s analyzer/tests -v
```

2つの短いWAVを生成してEnd-to-End確認:

```bash
python analyzer/tests/generate_sample_audio.py /tmp/MyMusicAnalyzerSample
python analyzer/analyze.py /tmp/MyMusicAnalyzerSample \
  --limit 1 --resume --segment-seconds 4 --segments 2 \
  --cache /tmp/MyMusicAnalyzerSample.sqlite3 \
  --output /tmp/music_features.json
```
