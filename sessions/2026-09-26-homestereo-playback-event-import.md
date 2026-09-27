# HomeStereo Playback Event Import

- 設定の「データ管理」→「再生データ」に、HomeStereoが出力したschema v1 Playback Events JSONの手動Importを追加した。保存前に文書全体を厳格検証し、最大100件のPreviewを確認した場合だけ現在Libraryに解決できる新規eventを適用する。
- `playback-history.sqlite3`を正本とし、schema v4でevent platformを後方互換追加した。旧row／旧Model JSONはiOS、HomeStereo eventはmacOSを保持し、再Exportでも保存済みplatformを使う。
- event ID重複はイベントと集計の両方を変更せず、未解決Trackは作らない。新規eventとfirst／last、manual／automatic、入口別、再生時間、skip／完走、日別集計は1回のSQLite transactionで更新し、失敗時はrollbackする。Favorite、Preference、Boredom、Shuffle非表示、連続／Repeat回数は維持する。
- `completed`は正規化せず、`playDuration >= max(3, trackDuration * 0.94)`との不一致を文書エラーとして全件拒否する。playCountは`playDuration >= min(30, trackDuration * 0.5)`のeventだけを加算する。
- 既存のiPhone 17e / iOS 26.5 Simulatorを使い、Import、冪等性、集計、platform、migration、rollback、既存Export契約の対象XCTest 19件が成功した。`generic/platform=iOS Simulator`のDebug buildと`git diff --check`も成功した。実機デプロイは行っていない。
