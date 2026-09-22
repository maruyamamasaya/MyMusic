# 再生中の詳細情報拡充

日付: 2026-09-23

## 作業

- Highlightの曲情報sheetへ、詳細metadata、音源仕様、Playback History、主要なTrack Feature、file identityを追加した。
- 通常Now Playingのアートワーク2面目へ曲metadataとファイル情報を追加した。
- 3面目のTrack Adjustmentsへ曲／音源情報と、BPM、Energy、主要分類、音量値、解析version・日時を追加した。
- 保存済み情報を表示する共通`TrackDetailPresentation`と`TrackDetailGridView`を追加した。新規解析、再スキャン、再生基盤の変更はない。

## 検証

- generic iOS Simulator Debug build: `BUILD SUCCEEDED`。
- iPhone 17e / iOS 26.5 Simulatorで`TrackDetailPresentationTests` 2件成功。
- 初回testで文字列補間漏れ2件を検出して修正し、同じ2件を再実行して成功した。
- XCTestDevicesは開始前後ともUUID folder 0件、合計12KB。新規test端末の作成・削除なし。
- `git diff --check`: 成功。

## 未確認

- 実機での3画面のスクロール、長いfile path、小画面、最大Dynamic Typeの見た目。
