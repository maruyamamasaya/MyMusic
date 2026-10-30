# Weeklyの先々週表示

- Context MATCH。Git root／status／CURRENT／ARCHITECTURE／関連View・Store・既存テストを確認。他の未コミット変更を保持。
- ArtistRankingViewの週Pickerにoffset -2「先々週」を追加。ホームタイルの説明も3週へ更新。
- 既存の任意offset対応week生成とStoreの直前週比較を共用し、先々週の前週比は3週前と比較。月曜〜日曜・50/30/20配点・日数加点・日本語期間・20組追加表示を維持。
- CURRENT／ARCHITECTURE更新。集計処理・保存形式の変更なし。
- 指定iPhone 17e Simulator UDID向けBUILD SUCCEEDED、git diff --check成功。既存処理への選択肢追加のみのためtest未実行、専用lintなし。
- test端末作成／削除0台、XCTestDevices合計12K。実画面・実機未確認、未デプロイ。
