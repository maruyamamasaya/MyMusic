# マイミュージックの空タイル非表示

## 作業

- ホームの「マイミュージック」に限り、対象曲が0件のタイルを非表示にした。
- 既存の`HomePerformanceSnapshotWorker`がDestinationごとに保持する対象曲有無を表示ポリシーへ渡し、追加のLibrary走査は増やしていない。
- あとで聴く、最近追加、未発見、リピート、お気に入り曲／アルバム／アーティスト、最近再生など、対象曲ベースの全項目へ同じ条件を適用した。
- ハイライトは通常再生候補がない場合に非表示にし、ライブラリ／アクティビティなどの固定導線は表示を維持する。
- 「選択してランダム再生」は実際の候補条件に合わせ、ジャンルを持つ通常再生対象曲がある場合だけ表示する。

## 検証

- `HomeCategoryTests` 9件と`HomeRepresentativeTrackPolicyTests` 6件、計15件が成功。空のマイミュージック項目だけが除外され、他カテゴリの固定導線が残ること、ジャンルなしの曲だけでは「選択してランダム再生」を表示しないことを確認した。
- generic iOS Simulator Debug build成功。
- 共有DerivedDataは別buildによりlock中だったため、既存processやdataを変更せず、`/tmp`のタスク専用DerivedDataでbuild／testを行った。
- 既存の`MusicHistoryView.swift`にSwift 6 language modeでerrorとなるasync／await警告がある。今回の変更箇所ではない。

## 未確認

- 実機上で、対象曲の追加・削除直後にタイルが出現・消失する視覚確認は未実施。
