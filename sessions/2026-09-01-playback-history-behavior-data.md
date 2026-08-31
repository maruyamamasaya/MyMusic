---
date: 2026-09-01
topic: playback-history-behavior-data
---

# Playback History behavior data

## 実施内容

- `PlaybackHistory` に `firstPlayedAt`、日別集計、manual / automatic集計、入口別集計を追加した。
- 入口分類は `PlaybackStartKind` と `PlaybackStartSource`、セッション開始文脈は `PlaybackStartContext` で型安全に扱う。
- 日別集計は再生開始があった日だけ `PlaybackDailySummary` として保持し、直近7日 / 30日の値は保存せず `PlaybackHistoryStore` の集計APIで算出する。
- 日別集計は `PlaybackHistoryStore` で400日分を保持し、再生開始時に古いkeyを整理する。
- `PlayerStore` は再生セッションごとに開始文脈を保持し、既存の再生開始・曲変更・停止・background時の保存経路へまとめて反映する。
- 主要入口（search / album / artist / playlist / shuffle / station / highlight / history / library / workLibrary / home）からの `playQueue` 呼び出しに開始文脈を付与した。
- 旧PlaybackHistory JSONは新field欠落を既定値でdecodeし、既存 `playbackEvents` から `firstPlayedAt` と日別集計を復元する。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/MyMusicDerivedData CODE_SIGNING_ALLOWED=NO build-for-testing` は成功。
- `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' ... test` はCoreSimulatorがSimulator runtimeを検出できず失敗した。コード上のtest失敗ではなく、`simdiskimaged`不調により指定destinationを見つけられなかった。

## 未解決 / 注意

- 実行XCTestはSimulator復旧後に再実行が必要。
- 入口別集計の永続形式は将来source追加でdecodeを壊さないためraw string keyにしている。アプリ内部の呼び出しはenumを使う。

## 運用決定（CSV）

- エクスポート見出しの運用定義を `種類,日時,曲名,アーティスト,再生回数,値,詳細` に固定し、解析データの再利用前提とする。
- `楽曲別再生行動` と `楽曲別再生入口` を現行CSVへ追加し、`再生回数/詳細` の運用ルールを合わせて出力する。
- 既存CSVインポートは未対応のため、この定義が現時点の「正しいCSV形式」となる。
