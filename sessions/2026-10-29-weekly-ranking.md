# Weeklyランキング Beta

- 要求はMyMusicにMATCH。Git root確認済み。開始前からの再生出力先表示・HomeView・AppIcon等の未コミット変更を保持。
- アクティビティへWeeklyタイル追加（既存ランキング背景を共用）。既存ランキング画面／Store／Serviceに期間入力を追加し、カード・詳細・再生を共用。
- ユーザー指定により今週（途中経過）と先週の2週を切替。端末の現地時刻、月曜0時以上〜翌月曜0時未満、event開始日帰属。
- インスト／ボーカル設定を使用せず通常曲を合算。作業用・ハイレゾ除外、全登録曲数分母と40/10/30/20配点・3方式・top100を維持。
- 回数は詳細eventの実聴秒数が通常再生のmin(30秒, 曲長×0.5)到達、時間は詳細eventの実聴秒数。累計だけの旧履歴・未確定再生は対象外。日別summaryは開始回数のため使用しない。
- Good／お気に入りの時系列記録がないため両週とも現在値を使用。週内に聴いていないアーティストも現在評価により総合へ載り得る。期間別評価の復元は未実装。
- 永続化・JSON契約・外部依存・音声処理変更なし。CURRENT／ARCHITECTURE更新。

## 検証

- 指定iPhone 17e Simulator destinationでBUILD SUCCEEDED。
- 並列無効・指定UDIDでArtistRankingTests 6件、HomeCategoryTests 9件、合計15件成功。
- 月曜開始／日曜終端／翌月曜除外／先週切替、ジャンル合算、累計混入防止、回数閾値と実聴秒数を検証。
- git diff --check成功。専用lintなし。実表示・実機は未確認、未デプロイ。
- 初回sandbox内buildはキャッシュ／CoreSimulatorアクセス制限で失敗。権限拡張後build／test成功。
- XCTestDevices開始前UUIDフォルダなし・合計12K、終了後もUUIDフォルダなし・合計12K。作成／削除test端末0台、データ削除なし。
