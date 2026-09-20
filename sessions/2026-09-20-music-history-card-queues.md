# 音楽史カードの一時Queue

- `MusicHistoryCardCandidate`に表示用Trackと再生候補Track ID列を分離して保持。12種のカード条件ごとに候補を順位付けし、代表曲を先頭に置く。1年前の今日では同日、±1日、±3日の順に候補を集める。今月の音は今月再生済みかつFeatureのある曲を傾向適合度で並べる。
- タップ時に`MusicHistoryCardPlaybackService`が現在LibraryへIDを再解決し、security scope下で可読ファイルだけを最大10曲に絞る。候補が空ならPlayerStoreを呼ばない。非空ならShuffleをOFFにし、既存`playQueue`を手動／History入口で開始する。Playlist、履歴schema、通常Shuffle等は変更していない。
- iOS Simulator向けscheme build成功。既存iPhone 17e Simulatorで`MusicHistoryCardServiceTests` 23件成功。`git diff --check`成功。専用lintはなし。
- 再生候補IDの上限処理を省メモリ化した後、同schemeのbuildと関連テスト3件も成功。
- 実機でのiCloud File Providerの可読性、カードタップの手触りと大量履歴での性能は未確認。
- XCTestDevicesの新規作成・削除は0件。開始時と終了時の残量は12KB。
