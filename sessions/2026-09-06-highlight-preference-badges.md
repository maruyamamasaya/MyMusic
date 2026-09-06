# Highlight Good／Bad数値バッジ

## 変更

- ハイライト画面のGood／Badボタンへ、現在の`playbackPreference`の絶対値を有効側だけ数値バッジとして表示した。
- Goodは緑、Badはオレンジで既存の状態色を維持し、未評価側は通常アイコンを表示する。
- VoiceOverの値を「未評価」または「Good／Bad n、10段階中」にした。

## 検証

- iPhone Simulator向けDebug build成功。
- `git diff --check`成功。
