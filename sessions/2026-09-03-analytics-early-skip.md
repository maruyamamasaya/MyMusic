# Analytics Early Skip

## 作業

- `skipped = true AND play_duration <= 30`をEarly SkipとしてQueries層で集計した。
- 信頼開始日2026-09-01より前のイベントは総再生回数だけに含め、Early Skipの分子・分母から除外した。
- Overviewへ総数・率・曲ランキング、Tracksへ曲別回数・率とソートを追加した。
- Tracksの期間選択に既存APIが対応済みの「今日」を追加した。

## 検証

- Analytics unittest: 26件成功。
- 10秒／30秒、31秒、completed、信頼開始日前、詳細イベントなし、期間指定、Tracksソートをテストした。

## 未解決事項

- なし。
