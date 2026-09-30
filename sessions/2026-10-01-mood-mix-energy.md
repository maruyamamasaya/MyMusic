# Mood Mix Energy のSemantic対応（2026-10-01）

- Energy値がないSemanticライブラリでEnergy Mixが無効になる問題へ対応。MoodStationServiceのMood Mix専用scoreで、Library内aggressive percentileの高さ60%＋calm percentileの低さ40%を評価し、0.72以上を候補にする。
- 両軸の値と有効な分布が揃う曲はSemanticを優先し、比較できない曲は既存DSP Energy percentileへfallbackする。欠損・無効値を低いcalmとして扱わず、小さすぎる分布rangeは従来どおり除外する。
- 最大25曲、Overplay補正、jitter、Artist分散は維持。Mood Station本体、保存Energy、解析JSON、音源は変更しない。CURRENTとARCHITECTUREへ反映した。
- 回帰テスト3件を追加。初回はfixtureのpercentile順位と期待値が不整合で2件失敗したためfixtureを修正し再実行。既存の起動済みiPhone 17 Pro / iOS 26.5でMoodStationServiceTests 15件＋StationStoreIntegrationTests 6件が成功。並列無効、worker 1。generic iOS Simulator Debug buildもBUILD SUCCEEDED。
- 統合解析JSON 7,886曲に同じ条件を適用すると2,212曲が該当（通常shuffle適格性による除外前）。現在端末上のLibraryや聴感の検証ではない。
- XCTestDevicesは開始前UUID 1件・3.5G、終了時も1件・3.5G。作成0件、削除0件。Simulator稼働中であり既存データは削除しない。専用lint設定なし、git diff --check成功。
- 作業開始前から複数の未コミット変更あり。既存変更を保持し、この作業ではService、関連テスト、CURRENT、ARCHITECTURE、このsessionのみ変更。聴感確認は未実施。

## 実機デプロイ

- ユーザーの明示依頼でgit status → check-iphone.sh成功 → deploy-iphone.shを実行。未コミット変更を保持した現在の作業ツリーをデプロイ。
- Project: MyMusic.xcodeproj、Scheme / Product: MyMusic、Debug、Bundle Identifier: maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C。実機Build / Install / Launchすべて成功。
- デプロイ時のアプリ・署名設定変更なし。テスト再実行なし、test端末作成・削除0件。前回確認時のXCTestDevices合計容量3.5G。端末上でのEnergy選曲の聴感は未確認。
