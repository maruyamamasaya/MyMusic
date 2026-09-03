# Analytics JST期間フィルター

## 作業

- Overview／Tracksの「今日」「7日」「30日」と期間指定を、日本標準時（JST、UTC+09:00）の日付境界へ統一した。
- 日別・時間帯別集計とPlayback詳細指標の信頼開始日判定もJSTへ統一した。
- UTCで保存する再生イベントと、JST当日0時付近の境界を検証する回帰テストを追加した。
- Overviewの日別再生数へ曜日の2段表示、土曜／日曜・日本の祝日の色分け、棒から1日表示へ切り替える操作を追加した。

## 検証

- `analytics/.venv/Scripts/python.exe -m unittest discover -s tests -v`: 24件成功。
- `node --check web/app.js`: 成功。
- ローカルサーバーを実ブラウザで開き、月日／曜日の2段表示、土曜の青系・日曜の赤系表示、`2026-09-03`の棒から開始日・終了日が同日となる1日表示への切替、console errorなしを確認した。
- SwiftコードとXcode projectは変更していないため、Xcode buildは対象外。

## 制約・未解決事項

- Analyticsの日付表示は日本での利用を基準とし、利用端末やサーバーOSのローカルタイムゾーンには追従しない。
