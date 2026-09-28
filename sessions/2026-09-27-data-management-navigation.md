# データ管理画面の整理

## 作業

- データ管理トップを、App外バックアップ／Analytics同期と、データ種別ごとの5つの入口へ整理した。
- ライブラリとTrack識別、プレイリスト、再生データ、解析データ、設定とプリセットをそれぞれ子ページへ分けた。
- 既存の読み込み、書き出し、共有、結果表示の処理は共通の詳細View内に維持した。
- ライブラリFingerprintの取得は、ライブラリ子ページを開いた時だけ行うようにした。
- 再生イベントJSONは全体検証後に開始日／終了日を選び、端末のローカル日付で期間内のイベントだけをPreview・保存するようにした。
- Previewと保存には同じfilter済み文書を使い、保存済み`eventId`の重複除外とLibrary未解決Trackの除外を維持した。
- Playback Preferences JSONには曲単位の日時がないため、期間指定は適用せず既存のTrack ID単位mergeを維持した。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`
- iPhone 17e / iOS 26.5 Simulatorで`PlaybackEventImportTests` 7件: 成功。ローカル日付境界、期間外除外、Previewと保存の一致、event ID冪等性、未解決Track、厳格検証、transaction rollbackを確認した。
- `git diff --check`: 成功。
- XCTestDevicesは開始前後とも既存1件のみで、新規作成・削除は0件。残容量は3,646,900 KiB。既存Simulatorが実行中だったため既存領域には触れていない。

## 未確認

- 実機でのDynamic Type、長い補足文、各子ページへの画面遷移の見た目は未確認。
