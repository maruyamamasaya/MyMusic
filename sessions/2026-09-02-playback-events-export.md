# Analytics Playback Events JSON Export

## 作業

- `MusicDataExportService`へAnalytics schema v1専用の`playbackEventsJSON`を追加した。
- 保存済みPlayback EventのID、開始日時、実聴秒数、完走／Skip、入口、選択種別を使い、現在のLibraryから曲名、Artist、Album、曲長を補完する。
- 設定の「データ管理」→「再生データ」に「Analytics用再生イベントを書き出す」を追加した。
- 既存の簡易再生履歴JSON、履歴保存、再生処理、AnalyticsからiOSへの書き戻しは変更していない。

## 検証

- filename、root／event schema version、必須field、値のmapping、Analytics契約外fieldの非混入を確認するXCTestを追加した。
- Windows環境のため`xcodebuild`は利用できず、XCTest実行とSwift buildは未検証。
- `git diff --check`と変更範囲を確認した。

## 制約・未解決事項

- Playback Eventにsession IDを保存していないため、optionalの`sessionId`は出力しない。
- 現在のLibraryでTrack IDを解決できないeventは、必須の曲metadataを補えないため出力しない。
