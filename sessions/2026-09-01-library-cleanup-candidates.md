# ライブラリ整理候補 M2

## 作業

- Playback Historyの日別集計に保存済みのearly skip件数とmanual play件数から候補を導出する`LibraryCleanupCandidateService`を追加した。
- 設定の分析／音楽史と同じsectionに「ライブラリ整理候補」を追加した。
- 候補一覧でアートワーク、曲／アーティスト／アルバム、early skip、総skip、総再生、最終再生、評価を表示し、既存`PlaybackPreferenceButton`を再利用した。
- 境界条件、評価非依存、並び順、読取時と評価変更時の行動データ不変をXCTestへ追加した。

## 検証

- Cloud: Swift frontendのparse、`git diff --check`、`git status`を実施。
- ローカルMac未検証: Xcode build、Simulator XCTest、Dynamic Type / Light・Dark Modeを含む実機相当UI。

## 制約

- 自動Bad、評価変更、非表示、削除、shuffle除外、Boredom、Permanent Hide変更は実装していない。
- Overplay、Preference Drift、Preference Weight変更、Shuffle / Quick Play / Station補正は対象外。
