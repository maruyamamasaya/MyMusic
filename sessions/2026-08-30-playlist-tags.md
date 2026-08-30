# Playlist tags

## 作業

- `Playlist.tags`を後方互換なoptional decode相当の空配列既定値で追加した。
- tagの空白正規化、大文字小文字・幅・diacriticを無視した重複排除、1Playlist最大20件・1件40文字の制約を追加した。
- 通常／作業用Playlist一覧、Playlist詳細、曲の追加先選択にtag表示・編集・1tag絞り込みを追加した。
- 曲の追加先選択へPlaylist名検索も追加した。
- JSON / Markdown import / exportでtagを保持し、旧文書のfield欠落は空tagとして扱う。
- `PlaylistStore`の保存を更新順に直列化し、高速な連続更新で古いsnapshotが後から保存されないようにした。

## 再生中更新の境界

- Playlistから再生を開始すると、`PlayerStore`は`[Track]`のqueue snapshotを所有する。
- tag編集は`Playlist.tags`だけを更新し、`trackIDs`や`PlayerStore`には触れない。
- 再生中にtagを変更しPlaylistから次曲を削除しても、現在曲と既存queueが維持されることをintegration testで確認した。変更後のPlaylist内容は次回そのPlaylistから再生するときに反映される。

## 検証

- 旧Playlist dataのdecode、tag正規化・重複排除、global tag件数、絞り込み、連続保存の最終snapshot、JSON / Markdown round-tripをXCTestへ追加した。
- iPhone 17 / iOS 26.5 Simulatorの全XCTest: `TEST SUCCEEDED`。
- iOS Simulator Debug build: `BUILD SUCCEEDED`。
- `git diff --check`: 問題なし。
- 専用lintはリポジトリに存在しないため未実行。Analyzer変更はないためPython unittestは対象外。

## 既知の制約

- tagの一括名称変更、色、階層、複数tagのAND / OR絞り込みは未実装。
- 実機でのDynamic Type、VoiceOver、再生しながらの長時間操作は未確認。
- 作業開始前から存在した気分ステーション年代指定の未コミット変更には触れていない。
