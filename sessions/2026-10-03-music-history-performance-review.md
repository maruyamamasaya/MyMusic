# iPhone音楽史の性能確認

## 確認結果

- ユーザーの体感報告を受け、iPhoneアプリの音楽史を静的調査した。実機の時間・CPU・memoryは未計測で、原因の確定ではない。
- `MusicHistoryView.rebuildSnapshot`はMainActor上でAnalytics全体と年・月ランキング、Discovery、全曲の履歴、全日カレンダー、Time Capsuleを同期生成する。トップで未表示の詳細も先に構築し、履歴量に応じてUIを待たせる候補となる。
- 音楽史が使うのはAnalyticsの月groupだけだが、共通makeSnapshotは直近7／30日集計や評価・非表示曲のsortも実行する。
- 今日のカードはMainActor外で生成するが、その完了まで初期loadingを解除しない。画面を開き直すとView stateの再生成に伴い再集計する構造で、共有cacheはない。
- dataRevisionはbody評価で履歴entry全件からevent件数を合計する。event追加時には全snapshotとカードを再構築する。総再生時間更新などでもentriesのObservationからbody再評価・件数走査は起こり得るが、件数不変ならtask IDは変わらず再集計は起動しない。
- Artworkは既存の画像cacheとMainActor外decodeを利用する。現時点では集計経路を優先して調べる根拠がある。

## 推奨する改善順序

1. 音楽史専用の値snapshot集計をMainActor外へ移し、不要なAnalytics集計を避ける。
2. 年・月の表示をカード完了前に出し、全曲詳細・カレンダー等の遅延生成を検討する。
3. 件数全走査を軽量revisionへ置換し、入力revisionに基づく再利用と取消を設計する。件数が同じmetadata／feature変更も検出できるようにする。

## 検証と変更範囲

- 実装・構造・データ契約の変更なし。既存のWatch関連未コミット変更を保持した。
- 調査記録のみ追加。build／testは実行していない。test端末の作成・削除は0台。
- 実機で開く時間、スクロール、再生中の曲切替時のhitchを測る必要がある。
