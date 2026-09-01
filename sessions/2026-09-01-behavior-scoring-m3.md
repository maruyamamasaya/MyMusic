# Behavior Scoring M3

## 作業

- Good / Badの選曲重みを`PlaybackPreferenceWeightPolicy`の-10〜+10固定テーブルへ分離した。
- 日別集計からOverplay（7日＋直前56日）とPreference Drift（30日＋それ以前）を再計算する純粋なScoringと`PlaybackBehaviorAnalyzer`を追加した。
- Overplayで70%まで補正するStable Preference Driftと、Good、最近5件、historical 8件、stable score 0.5の候補条件を一元化した。
- 設定に「再生傾向」を追加し、Overplay候補とPreference Drift候補を別Sectionで表示した。
- XCTestを追加した。M2の候補モデル／Service、MoodStationService、各選曲経路、SQLite schemaは変更していない。

## 検証

- Cloud: Swift parse、独立Scoringコードのtypecheck、`git diff --check`、`git status`。
- ローカルMac未検証: Xcode build、Simulator XCTest、実機、実データ。

## 未解決事項

- M4で`PreferenceWeight * OverplayFactor`を選曲経路へ接続する。M3の接続点は`PlaybackPreferenceWeightPolicy`、`OverplayScoring`、`PlaybackBehaviorAnalyzer`。
