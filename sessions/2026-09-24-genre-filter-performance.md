# ジャンル表示切り替え性能改善

## 背景

- 約20,000曲、約20ジャンルで「ジャンルごとの表示」の切り替えが重い。
- 従来は切り替えごとに全曲のジャンル文字列を分解し、通常曲のAlbum／Artist／Genre／Composerをgroup・localized sortから再構築していた。
- 作業用BGM／ハイレゾcatalogも設定変更と無関係に毎回再生成していた。
- 設定画面のcomputed propertyもSwiftUIの再評価ごとに全Trackを走査していた。

## 変更

- `GenreLibraryFilterIndex`に通常ライブラリ構造、曲順に対応するジャンルfilter key、作業用／ハイレゾcatalogを保持する。
- Library load／scan完了時だけ索引を作り、ジャンル切り替え時はTrack IDによる線形絞り込みと既存分類構造の縮約だけを行う。
- 全ジャンル表示時は通常ライブラリsnapshotを再利用する。
- AlbumのArtwork、年、legacy IDは表示曲から再選択し、従来の再構築結果との表示互換性を保つ。
- `LibraryStore`の選択可能ジャンルと固定分類を完成ライブラリ更新時にcacheする。

## 検証

- generic iOS Simulator Debug build: 成功。
- iPhone 17e / iOS 26.5 Simulator、`LibraryGenreFilterTests`: 3件成功。
- Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）向けDebug buildと`maruyama.MyMusic`のinstall: 成功。端末ロック中のため自動launchはiOSに拒否され、手動起動確認は未実施。
- 索引からの絞り込みと新規`MusicLibrary.build`のTrack／Album／Artist／Genre／Composer結果が一致するtestを追加。
- 専用lint設定は存在しないため未実施。
- 実機の約20,000曲ライブラリによる切り替え時間、CPU、allocationは未計測。
- XCTest前の`XCTestDevices`はUUID folder 0件、合計12KB。既存Simulatorを1台だけ使用し、新規test端末は作成していない。
