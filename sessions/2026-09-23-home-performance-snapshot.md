# Home性能改善 snapshot計算

## 背景

約10,000曲での残存候補を調査し、HomeがLibrary／Playback History／Preference変更時に代表画像、各入口候補、Highlight画像、MIX、今日の集計をMainActor上で連続計算していることを確認した。MIXは全候補の63日分Overplay集計と全件sortを含み、再生開始／完了時のframe hitch候補だった。

## 変更

- `HomePerformanceSnapshotWorker` actorを追加し、Storeから取得したTrack／Album／Artist／History／Preference／Favorite／Listen LaterのSendable snapshotをMainActor外で処理する。
- 通常shuffle適格曲を1回だけ抽出し、Quick／未再生／Repeat／Favorite、Highlight Artwork、MIXで共有する。作業用／ハイレゾ、短曲、shuffle非表示の既存分類を維持する。
- Overplay scoreと自動選曲weightを候補ごとに1回だけ計算し、`MixSelectionService.allQueues`のDaily／Rediscovery／My Favoritesで共有する。
- Homeは完成snapshotだけを比較してstateへ反映する。新しい通常更新では先行通常Taskと画像ローテーションTaskをキャンセルする。Home非表示／backgroundとView消失時もTaskを停止する。
- 60秒ごとの代表画像ローテーションは別Taskで実行し、MIXと今日の再生集計を省略する。日付が変わった場合だけ完全snapshotを更新する。
- 選曲Policy／Scoringの値型を`nonisolated`として明示し、actorから同期的に使える純粋計算境界に合わせた。永続化、再生queue、MIX内容の契約は変更していない。

## 検証

- `git diff --check`: 成功。
- generic iOS Simulator Debug build: **BUILD SUCCEEDED**。今回追加したactor isolation警告はなし。App Intents metadata警告のみ。
- iPhone 17e / iOS 26.5 Simulator、並列無効・worker 1で対象XCTest 22件成功、失敗0。
  - Home代表表示／snapshot: 5件。
  - MIX: 5件。
  - Playback History／10,000曲queue／再生遷移: 12件。
- 新規testでは、短曲／作業用／shuffle非表示の除外、未再生・Favorite・作業用表示、前回代表画像の維持、MIX候補、今日の回数、ローテーション時のMIX／集計省略を確認した。
- XCTestDevicesはtest前後とも12 KB。新規UUID folder 0、削除0。

## 未確認

- 実機約10,000曲でのSwiftUI Instruments／Time Profiler、再生開始・完了時のframe hitch、CPU／allocation比較は未実施。
- Home以外のSearch大量結果paginationと起動時library cache decodeは今回の対象外。
