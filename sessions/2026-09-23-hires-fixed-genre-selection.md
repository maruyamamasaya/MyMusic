# ハイレゾの固定ジャンル選択

## 作業

- ジャンル表示設定に、対象曲が存在する「作業用BGM」と「ハイレゾ」を「固定の専用分類」として表示するようにした。
- 固定分類はロック表示とし、「すべて解除」、個別操作、ジャンル表示プリセットの適用では解除されない。
- ジャンルタグが「ハイレゾ」の曲だけでなく、保存済み音源仕様からHi-Resと判定された曲も固定分類の表示対象にした。
- 固定分類は通常ジャンルの選択件数、総数、プリセット内の有効ジャンル件数から除外した。
- 作業用／ハイレゾの専用catalogと通常ジャンルfilterの分離を確認するXCTestを更新した。

## 検証

- `git diff --check`: 成功。
- iPhone 17e / iOS 26.5 Simulator 1台、並列無効で`LibraryGenreFilterTests`を開始した。
- 初回は、別作業の未コミット`HiResLibraryView.swift`が、その時点では存在しなかった`HiResNowPlayingView`を参照していたためbuild失敗した。既存変更は修正・破棄していない。
- 作業中に別作業側の`HiResNowPlayingView.swift`が追加された後、同じ条件で一度だけ再実行した。アプリ／埋め込みWatchのbuildが成功し、`LibraryGenreFilterTests` 2件が成功した。

## 未確認

- 実機での固定分類表示、VoiceOver、Dynamic Typeの見た目。
