# Library曲一覧のfilter／sort

## 作業

- 「ライブラリ → 曲」に、すべて／お気に入り／Good／Bad／再生済み／未再生／最近追加の単一filterを追加した。
- 既存の曲名／Artist／Album／追加・更新日／ランダム順に、再生回数の多い順、最近再生した順、曲の長さが短い順を追加した。
- 既存検索へGenreを追加した。検索とfilterは併用できる。
- Track、Preference、HistoryのsnapshotをMainActor上で取得し、検索・filter・sortの全件処理は既存どおり`Task.detached`で行う。Store revisionをrequestへ含め、処理中に正本が変化した古い結果を破棄する。
- 表示は既存の100曲単位の段階追加を維持する。Library、Preference、Historyの正本は変更しない。

## 検証

- generic iOS Simulator Debug buildでiPhone／Watchを含む`BUILD SUCCEEDED`を確認した。AppIntents未使用による既知のmetadata warning以外のSwift warningなし。
- iPhone 17 Pro / iOS 26.5 Simulator、並列test無効で`SongsViewArrangementTests` 3件成功。Favorite、Genre検索、未再生、最近追加、再生回数順、最近再生順を確認した。
- XCTestDevicesは開始時UUID folder 0件、合計12KB。既存Simulatorを1台だけ使用した。

## 未検証

- 大規模な実ライブラリでの操作感、toolbarの視認性、各filterとsortの実機UIは未確認。
