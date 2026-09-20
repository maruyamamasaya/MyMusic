# ホームの本日再生表示（2026-09-21）

- ホームをインラインタイトルにし、右側へ一行の「今日 N回 · X分／X時間Y分」を追加した。余分なヘッダー領域は作らない。
- `TodayPlaybackSummaryService`で端末ローカル日付の再生開始回数と、同日開始の終了済み再生イベントの実聴時間を集計する。履歴の開始・終了と日付変更時に表示を更新する。再生中の時間は終了まで含まれない。
- `generic/platform=iOS Simulator`のiOS／組み込みWatch build成功。既存のiPhone 17e Simulatorで対象のUnit Test 1件成功。並列testなし。
- `XCTestDevices`で今回作成・削除したUUIDフォルダは0件、終了時合計容量12K。実機でのナビゲーションバーの見た目、Dynamic Typeは未確認。
