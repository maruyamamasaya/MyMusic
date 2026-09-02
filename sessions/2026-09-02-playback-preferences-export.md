# Playback Preferences JSON Export

## 作業

- `MusicDataExportService`へ、再生傾向の現在値だけを出力する`playbackPreferencesJSON`を追加した。
- 出力契約はrootの`schemaVersion`、`exportedAt`、`tracks`とし、各Trackは`trackId`、`playbackPreference`だけを持つ。
- 設定の「データ管理」→「再生データ」に「再生傾向を書き出す」を追加した。
- 既存の再生履歴JSON、Playback History保存、Good／Bad操作、選曲ロジック、Analytics Importは変更していない。

## 検証

- filename、schema version、Track ID順、0／負値、お気に入り等の非混入を確認するXCTestを追加した。
- Windows環境のため`xcodebuild`は利用できず、XCTest実行とSwift buildは未検証。
- `git diff --check`と変更範囲を確認した。

## 未解決事項

- Analytics側でのPlayback Preferences ImportとPlayback Eventとの結合は将来対応。
