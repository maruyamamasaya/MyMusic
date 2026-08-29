# 2026-08-29 音量ノーマライズ

## 作業

- 既存Mac AnalyzerへFFmpeg loudnormによる全曲Integrated LUFS / True Peak解析を追加した。
- target -14 LUFS、無補正 -17...-11 LUFS、最大±4 dB、ceiling -1 dBTPの独立ポリシー関数を追加した。
- schema v1とTrackFeatureへ任意の3項目を追加し、旧JSON decode、Semantic v2との双方向mergeを維持した。
- SQLiteへ独立loudness cacheを追加し、既存DSP cache曲はラウドネスだけbackfillするようにした。
- AudioPlayerServiceへfadeとEQから独立した固定ゲイン段を追加し、PlayerStoreがTrack IDごとの値を曲切替時に準備するようにした。
- 設定画面へ初期OFFのToggleと説明を追加し、UserDefaultsへ保存した。

## 検証

- `PYTHONPATH=analyzer analyzer/poc/.venv/bin/python -m unittest discover -s analyzer/tests -v`: 36件成功。
- FFmpegで生成した一時WAVを実測し、`integratedLUFS=-41.05`、`truePeakDBTP=-38.05`、`normalizationGainDB=+4.0`を取得。
- iPhone 17 / iOS 26.5 Simulator XCTest: 46件成功。
- iOS Simulator Debug buildとtest build成功。

## 未解決・制約

- 実ライブラリ全曲での解析所要時間、実機での聴感、background / route changeを含む実再生回帰は未確認。
- True Peak ceilingは元音源と固定ゲインを対象とし、後段のユーザーEQで増えるピークは保証しない。
- システムPython 3.10.4では既存Semantic testが`hashlib.file_digest`不足で失敗するため、リポジトリ既存のPython 3.12 venvで全件確認した。
