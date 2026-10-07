# ホームのおすすめ引き直し

- Context Guard: MATCH、Git root一致。前タスクの設定整理の変更を維持。
- ユーザーの範囲修正に従い、pull-to-refreshはおすすめ代表曲・画像とMIXの引き直しのみ。Library同期、Playlist再読込、今日の集計の強制更新は含めない。既存の自動更新は維持。
- HomeViewの既存snapshot Taskをawaitし、生成と反映の間はrefresh表示を維持。workerのcancel／最新request優先を維持。PlayerStoreへの操作なし。
- 一時的なseedをMixSelectionServiceへ渡す。初期seed 0では既存の日別hashをそのまま使う。手動引き直し後はView内のseedを自動更新でも維持。永続化変更なし。
- 初回の追加テストで隣接seedの順位が同じになる問題を検出。非zero seedにhash avalancheを適用して修正。再確認は17件全成功（MixSelectionServiceTests 9、HomeRepresentativeTrackPolicyTests 6、PlaybackDurationSummaryTests 2）。
- generic iPhone／Watch Simulator Debug build成功。修正後の対象test buildも成功。git diff --check成功。専用lintなし。
- 既存iPhone 17e Simulator 1台を使用、parallel testing無効、workers 1。XCTestDevices開始前UUID folderなし、12 KiB。終了後も新規UUID folderなし、12 KiB。テスト端末作成／削除0台。その他Xcodeデータ削除なし。
- 候補不足や既存ranking条件では同じ曲が選ばれる場合がある。実機のpull操作・Dynamic Typeは未検証。今回の変更の実機deployは未実施。
