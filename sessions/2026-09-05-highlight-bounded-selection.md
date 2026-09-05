# Highlight bounded selection

## 原因と変更

- `HighlightSelectionPolicy.orderedTracks`が全候補を1曲ずつ選び、各回に残候補をfilter／reduce／removeしていたためO(n²)相当だった。呼び出し元の`HighlightPlayerStore`はMainActorで、起動・mode切替・reshuffle時のUI stallになり得た。
- 全候補をO(n)評価してband bucketへ分け、bounded min-heapで最大150曲をO(n log k)抽出し、最大40曲だけGreedy多様化する方式へ変更した。
- Track単体のArtist／Album正規化を事前計算し、Greedy比較中の文字列foldingを廃止した。
- Storeはimmutable snapshotを作り、pure selectionをdetached taskで実行する。generation／mode照合とcancelで古い結果を採用しない。mode切替では現在曲までを維持する。
- Highlight Candidateの30秒区間解析・cache・prefetchロジックは変更していない。

## 検証

- HighlightSelectionPolicy XCTest 19件成功。mode band、極端Preference、多様性、特徴距離、発掘、Shuffle中立性、Recent Highlight、重複なし、pool不足を確認。
- synthetic 5,000／10,000曲テストはSimulator上でfixture生成を含め約0.121秒／0.240秒。各入力でpool <= 150、queue = 40、Greedy比較 <= 6,000を確認した。
- Highlight選曲・再生選択・特徴Storeの関連XCTest 30件成功。
- iPhone Simulator向けDebug build成功。
- 全XCTestも実行したが、Highlight関連は成功し、既存の`StationStoreIntegrationTests`と`LibraryGenreFilterTests`計10件が失敗した。今回変更したHighlight選曲コードとは独立したテストである。

## 残存事項

- 絶対時間は実機性能や履歴量で変動する。Debug集約ログで実Libraryのelapsedを継続確認できる。
