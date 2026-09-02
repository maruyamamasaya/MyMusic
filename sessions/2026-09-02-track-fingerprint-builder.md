# Track Fingerprint Builder

## 作業

- 既存`TrackIdentityService`へ保存済みFingerprint snapshot取得と、1曲単位のforeground作成APIを追加した。
- `TrackFingerprintBuildStore`で1日100曲上限、1曲ごとの進捗保存、download待ち／失敗集計、pause／resumeを管理する。
- データ管理に専用`TrackFingerprintBuildView`を追加し、画面離脱、scene非active、再生／Library load開始時にcancelする。
- iCloud取得は初期OFFの明示toggleとし、通常起動・Library scanではFingerprintを作成しない。
- Library JSONへ保存済み`audioFingerprint`だけをoptional出力する。Analyticsはfieldを検証・SQLite保存し、Tracksで有無を表示する。

## 検証

- 日次上限と進捗永続化、Library JSONのoptional fieldを確認するXCTestを追加した。
- AnalyticsはFingerprint保存・不正値拒否・既存DB migrationを含むPython unittest 12件が成功した。JavaScript構文確認も成功した。
- Windows環境のためXcode buildとXCTest実行は未検証。

## 制約・未解決事項

- iCloud download状態とsecurity-scoped accessは実機での確認が必要。
- AnalyticsのFingerprint重複候補表示とTrack ID aliasは未実装。
- 既存fingerprint algorithmはdurationと最大2 MBのdecoded PCMをSHA-256へ入力する。cross-platform互換は未定義。
