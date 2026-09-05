# ハイライト選曲のPreference／Overplay／Boredom統合

## 作業

- `HighlightPlayerStore`へ既存の`PlaybackHistoryStore`を注入した。
- ハイライトの初期生成、再シャッフル、末尾到達後の再生成、library更新時の追加曲を、通常shuffleと同じ重み付き順序へ変更した。
- 候補判定と重みは`isEligibleForRegularShuffle`、`preferenceWeightedShuffle`、既存Overplay計算を共有し、ハイライト専用の式は追加していない。
- 時刻指定テストのため、通常shuffle eligibilityの既存判定に`now`を渡せる入口を追加した。

## 検証

- iPhone 17 Simulatorで`PlaybackSelectionPolicyTests`と`PlaybackSelectionIntegrationTests`を実行し、全6件成功。
- Boredom中、永久非表示、期限切れBoredom、Preference／Overplay weight、queue内Track ID重複なしを統合テストで確認した。
- iOS Simulator Debug build成功。既存のasset catalog／Swift 6 isolation warningのみ。

## 未解決事項

- なし。ハイライト候補区間、解析、先読み、自動送りのロジックは変更していない。
