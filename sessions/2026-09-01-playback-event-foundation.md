# Playback Event Foundation

## 作業

- Playback Eventを開始／終了、実聴時間、完走率、skip／完走、開始種別／入口を持つ正式モデルへ拡張した。
- PlayerStoreで開始contextと開始時刻を保持し、再生セッション終了時に重複なくeventを確定するようにした。
- 日別集計へ完走、skip、early skip件数を追加し、旧JSONの欠落fieldは0でdecodeする。
- SQLite schemaをversion 2へ更新し、eventはevent IDによるappend、その他の集計はupsertする。曲別reset時だけeventと集計を削除する。
- migrationのsidecar、fail-closed検証、永久backup、transaction設計は維持した。

## 検証

- Cloud: 変更Swiftファイルの`swiftc -parse`、`git diff --check`。
- ユーザー指定に従いXcode build、Simulator XCTest、実機テスト、実データmigrationは実行していない。

## 未解決・ローカルMac確認

- 全XCTestとDebug build。
- schema version 1の実データcopyを用いたversion 2 migration、再起動後read-back、backup生成。
- 自然終了、次曲、skip、停止、background復帰を含む実再生eventの重複・時間精度。
- UI、Overplay、Preference Drift、候補判定、Shuffle／Station補正は本M1の対象外。
