# Weekly専用タイル背景

- MyMusicのWeekly画像設定依頼としてMATCH。Git root確認済み。
- imagegenスキル・built-in image_genで青紫のガラス製レコード表彰台、金の王冠、7日分のカレンダーを生成。文字なし、下部は見出し用の暗い余白。
- 生成元を保持し、HomeTileImages/activity-weekly-ranking-v1.png（1254×1254）へコピー。既存ローカル画像loaderでWeeklyだけ参照し、通常ランキングはactivity-rankingを維持。
- HomeCategoryTestsの画像mapping期待値、README、CURRENTを更新。集計／構造変更なし。
- 指定iPhone 17e Simulator destinationでBUILD SUCCEEDED、CopyPNGFileでアプリへの同梱確認。git diff --check成功。
- 今回は画像参照のみのためtest未実行。テスト端末作成／削除0台、XCTestDevices合計12K。実表示・実機未確認、未デプロイ。
- 画像フォルダは既存ルールでGit追跡対象外。ローカル資産として配置。

生成指定: 深い紺背景、青紫の光学ガラスと金属、レコードの三段表彰台、中央に王冠、背後に7枚のカレンダー。小さなタイルでも読める構図、文字・ロゴなし。
