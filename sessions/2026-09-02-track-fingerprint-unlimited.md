# Track Fingerprint作成上限の撤廃

## 作業

- `TrackFingerprintBuildStore`の1日100曲制限と日次件数のUserDefaults永続化を削除した。
- 専用画面から日次件数表示と上限による開始不可条件を削除した。
- 未作成候補を件数上限なく逐次処理するテストへ更新した。
- `CURRENT.md`、`ARCHITECTURE.md`、`README.md`を現行仕様へ更新した。

## 維持する停止条件

- 画面離脱、scene非active、再生開始、Library scan開始時の一時停止。
- iCloud取得の明示toggleと、1曲完了ごとのidentity registry保存。

## 検証

- iPhone 17 / iOS 26.5 Simulatorで、件数上限なく全候補を処理するFingerprint testは成功した。
- Debug test buildは成功した。
- 全XCTestでは無関係な`TrackPreferencePersistenceTests.testPreferenceImportMergesKnownTracksAndSurvivesReload`が一度失敗した。同testの単独再実行は成功した。
- `git diff --check`は成功した。
