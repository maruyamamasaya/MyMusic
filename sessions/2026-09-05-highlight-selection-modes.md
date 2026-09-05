# ハイライト専用選曲モード

## 作業

- `HighlightSelectionMode`と`HighlightSelectionPolicy`を追加し、直近Highlight減衰、特徴量補正、発掘補正、重み付き抽選をハイライト内に分離した。
- 通常shuffleのeligibilityとPreference × Overplay基本weight、既存Playback Event、TrackFeatureを読み取り再利用した。DB schemaと保存仕様は変更していない。
- ハイライト画面に4項目のSegmented Pickerを追加した。切替時は現在曲と再生を維持し、後続queueだけを再構築する。
- HighlightCandidate解析、候補位置、cache、別の部分、自動送り、フル再生、Playlist操作中の抑制は変更していない。

## 選曲

- 共通: Boredom／永久shuffle非表示を除外し、Preference × Overplay × RecentHighlight × Mode × Randomで並べる。
- RecentHighlight: 最新20再生は0.20倍、21〜50再生は0.60倍、それ以前は1.00倍。同じ曲は最新の出現位置を使う。
- アガる: energy／aggressive／brightと軽いdrumAndBass補正を0.6〜2.0倍で適用する。
- 穏やか: calm／ambient／pianoを0.6〜2.0倍で適用する。
- 発掘: 未再生、低再生、長期未再生を最大2.0倍で優遇する。

## 検証

- `HighlightSelectionPolicyTests`および既存`PlaybackSelectionPolicyTests`／`PlaybackSelectionIntegrationTests`をiPhone 17 Simulatorで実行し、全11件成功した。
- iOS Simulator Debug build成功。既存のasset catalog／Swift 6 isolation warningのみ。

## 未解決事項

- 実機でのタップ／レイアウト確認は未実施。
