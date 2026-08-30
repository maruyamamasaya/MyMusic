---
status: completed
date: 2026-08-30
---

# ジャンル設定時の再生負荷対策

## 作業

- 音割れ候補のうち、ジャンル設定適用時に`LibraryStore`のMainActor上で全曲filterとLibrary再構築を同期実行していた箇所だけを修正した。
- `GenreLibraryFilterService` actorへ表示曲抽出とAlbum / Artist / Genre / Composer再構築を移し、utility priorityで実行するようにした。
- 連続変更では前Taskをcancelし、request IDが一致する最新結果だけをMainActorへ反映する。scanやfolder変更時は保留中のfilterをcancelし、古い全曲snapshotによる上書きを防ぐ。
- actorから安全にLibrary snapshotを構築できるよう、派生Modelと`MusicLibrary.build`をnonisolatedなdata処理として明示した。
- Player、検索、Spectrum処理には変更を加えていない。

## 検証

- 連続して異なるジャンル設定を要求し、最後の設定に対応するTrack / Album / Artist / Genreだけが反映されるXCTestを追加した。
- iPhone 17 / iOS 26.5 Simulatorの全XCTestが成功した。
- iOS Device向けDebug buildが成功した。
- `git diff --check`成功。

## 未検証

- 実機で再生しながらジャンルプリセットを適用した際の聴感確認は未実施。
- Spectrum tapとSimeji入力は今回の限定修正の対象外。
