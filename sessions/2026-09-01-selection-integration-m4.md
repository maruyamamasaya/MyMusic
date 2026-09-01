# Selection Integration M4

## 作業

- `PlaybackSelectionPolicy`へshuffle（`1 - 0.50 * OverplayScore`）、Station（`1 - 0.20 * OverplayScore`）、Preferenceとの最終weightを集約した。
- 通常shuffle、Quick Play、Repeat、Favorite系shuffle、Selective Random候補、Genre Randomの選択曲より後、PlayerStoreの自動shuffle orderへOverplayを接続した。
- 未再生DiscoveryはOverplay対象にならない目的、Work Playbackは通常ランダムと分離された目的を維持し、Preferenceのみの選曲とした。
- Stationは純粋なMood thresholdでpoolを確定した後にOverplay factorをrankingへ掛け、既存artist回数／直前artist減点を維持した。
- derived scoreとweightは選曲処理ごとのDictionaryにだけ保持し、永続化model／SQLite schemaは変更していない。
- Selection Policy、時間経過によるweight回復、Station eligibility／ranking／artist diversityのXCTestを追加した。

## Cloud静的確認

- 変更Swiftの`swiftc -parse`、pure logicの`swiftc -typecheck`、`git diff --check`を実施した。
- 指示に従い、xcodebuild、XCTest、Simulator、実機、実データ選曲テストは実施していない。

## ローカルMacでの未検証

- Debug Build、全XCTest、SQLite migration、Playback Event、Library Cleanup Candidates、Behavior Scoring。
- Shuffle、Quick Play、Auto Queue、Station、Manual再生、Boredom / Permanent Hide。
- Simulator UI、実機。

## 不明点・未解決事項

- CloudではXcode SDKを使う統合typecheckを行っていないため、最終Qualificationで全体buildとXCTestが必要。
