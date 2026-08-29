# Track Adjustments 実装記録

日付: 2026-08-29

## 作業

- 通常Now Playingのアートワークtapを、既存2面を保持した3状態循環へ拡張した。
- Stable Track IDごとの`TrackPlaybackAdjustment`、遅延loadするStore、sharded JSON永続化Serviceを追加した。
- 開始位置、終了位置、前回位置、手動ノーマライズ微調整のUIと安全なvalidationを追加した。
- PlayerStoreで通常再生開始時の開始位置、0.5秒の音声進行eventによる終了位置判定、7秒間隔とpause／曲変更／backgroundの位置保存を統合した。
- 自動＋手動ゲインを±4 dBへ制限し、-1 dBTP ceilingを優先する計算を追加した。Mac Analyzer仕様と音源は変更していない。

## 検証

- iPhone 17 / iOS 26.5 Simulator: XCTest 54件、失敗0。
- Debug Simulator build: `BUILD SUCCEEDED`。
- Python 3.12 PoC venv: Analyzer / Semantic unittest 36件、成功。
- system Python 3.10では`hashlib.file_digest`非対応のためSemantic 17件が環境要因で失敗し、仕様どおりPython 3.12 venvで再実行して成功した。
- `git diff --check`: 成功。

## 未解決・実機確認

- 実音源での開始／終了境界の聴感と、fade設定の各組み合わせ。
- 実機background移行直後にiOSが処理を停止する場合の最終JSON書込み完了。
- 小画面・最大Dynamic TypeでTrack Adjustmentsをスクロール操作した際の使い勝手。
