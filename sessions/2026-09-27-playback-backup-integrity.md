# Playback Backup Integrity

- HomeStereo Playback Events JSON Importの追加・重複排除契約は変更せず、App外バックアップを独立した消失対策として強化した。
- manifest schema v2へ各payloadのSHA-256を追加し、Restore前にbyte数とhashの両方を検証する。旧schema v1はhashなしで読取可能とする。
- Playback SQLiteがある場合はintegrity checkに加え、非NULL event IDの空値・重複と`iOS`／`macOS`以外のplatformを拒否する。
- 同一byte数の改変検出、schema v1互換、macOS eventのBackup / Restore round trip、重複event ID拒否の対象testを追加した。
- 音源、Library cache、音楽フォルダbookmarkは従来どおり対象外で、HomeStereoとの4 JSONは完全復元ではなくアプリ間連携用とする。
- `ExternalBackupServiceTests` 11件は起動済みの既存iPhone 17e / iOS 26.5 Simulator 1台で、並列testなしで成功した。`generic/platform=iOS Simulator`のDebug buildも成功した。
- test前後の`XCTestDevices`はUUID folder 0件、合計12 KBで変化なし。新規test端末の作成・削除はともに0件。
