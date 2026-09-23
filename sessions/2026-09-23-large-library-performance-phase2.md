# 大規模ライブラリ性能改善 Phase 2

## 背景

約10,000曲、作業用／ハイレゾ分類、増加したメタ情報を前提に、ページ読み込みと全体性能の追加調査を行った。Phase 1で再生中の高頻度経路は改善済みのため、今回は画面遷移とSwiftUI再描画で残っていた全件処理を対象にした。永続化schema、音源、再生経路は変更していない。

## 調査結果と変更

- `WorkLibraryCatalog.tracks(for:)`と`HiResLibraryCatalog.tracks(for:)`は詳細画面を開くたびにcatalog全曲のDictionaryを生成していた。catalog snapshotにTrack ID索引を持たせ、要求されたID数に比例する解決へ変更した。
- Genre／Composer詳細も遷移時に通常ライブラリ全曲のDictionaryを生成していた。`LibraryStore`がPhase 1から保持する索引を使う共通APIへ合流した。
- HomeのPlaylist snapshot更新はPlaylistごとに通常／作業用の全曲Dictionaryを作っていた。通常と作業用を各1回だけ索引化して全Playlistで共有し、Playlist数に伴う全曲走査の増加を除去した。
- Album／Artist／Composer、作業用曲、ハイレゾ曲の検索結果を1回のbody評価内で使い回し、空判定・ForEach・再生queue生成が同じfilterを繰り返さないようにした。
- background actorから呼ぶ`WorkLibraryCatalogService.build(from:)`を`nonisolated`として明示し、実装の実行境界に合わせた。

## 検証

- `git diff --check`: 成功。
- generic iOS Simulator Debug build: **BUILD SUCCEEDED**。既存の`MusicHistoryView`のSwift 6 async警告とApp Intents metadata警告のみ。
- 既存のiPhone 17e / iOS 26.5 Simulator 1台、並列無効・worker 1で対象XCTest 6件成功、失敗0。
  - `HiResLibraryCatalogTests`: 4件。
  - `LibraryGenreFilterTests`: 2件。
- Track ID索引が未知IDを無視して要求順に既知Trackを返すことを、通常／作業用／ハイレゾの各経路で確認した。
- XCTestDevicesはtest前後とも12 KB。新規UUID folder 0、削除0。既存Simulator processが実行中だったが削除対象自体はなかった。
- `./scripts/check-iphone.sh`でVespera（iPhone 17e、UDID `00008150-000C54280E33401C`）のpaired／Developer Mode enabled／connectedを確認した。`./scripts/deploy-iphone.sh`によるDebug実機build、`maruyama.MyMusic`のinstall、launchはすべて成功した。端末のパスコード保護によりnotification proxy接続警告が出たが、デプロイ結果には影響しなかった。

## 未確認

- 実機の約10,000曲ライブラリを用いたTime Profiler／SwiftUI Instruments、画面遷移時間、検索入力中のallocation比較は未実施。
- HomeのMix、代表画像候補、Highlight画像候補には、データrevision時の意図的な全候補走査が残る。実測なしにcache寿命や更新契約を複雑化していない。
- 実機での作業用／ハイレゾ／Genre／Composer詳細、Playlist数が多いHome、Light/Dark ModeとDynamic Typeの手動回帰は未確認。
