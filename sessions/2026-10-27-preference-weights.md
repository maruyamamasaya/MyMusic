# Good選曲weightの再配分（Beta）

- 要求はMyMusicの選曲調整としてMATCH。Git rootを確認。既存の未コミット変更を保持。
- PlaybackPreferenceWeightPolicyの上限を15にし、+1〜+15を1.8/3.2/5.5/8.5/10/12/14/16/18/21/25/29/33/37/42へ変更。負評価と0、Overplay、Quick Play回数補正、候補条件は変更なし。
- 通常shuffle、Quick Play、MIX、Highlight等の共通weight利用先に反映。Mood Stationの順位、手動選曲、評価の表示・編集値は変更なし。既存queueを遡って作り直す処理は追加していない。
- 評価値は整数-10...15のまま。TrackPreferencePersistenceServiceのschema v2、MusicDataExportServiceの評価JSON v2、Import validation、ExternalBackupServiceの形式／コピー／復元は変更不要。倍率は派生値で保存されず、旧backupも復元後は新しい倍率で選曲する。旧版アプリへの15を含むデータの互換性は従来どおり保証しない。
- HomeStereoのdocs/data-interchange-contract.mdとMyMusic側の契約はcmpで本文一致（revision 5）を確認。追加のユーザー依頼でHomeStereoもGood側を同じ配分に変更し、共通契約revision 6を両Gitで同期。HomeStereoのBad式1÷(1−値)は維持。端末ガイドも更新。wire契約には変更なし。HomeStereoの検証詳細は同側sessionを参照。
- ARCHITECTURE、CURRENT、端末ガイドを更新。責務・永続化境界の変更なし、ADR追加なし。

## 検証

- 指定iPhone 17e / iOS 26.5 / EB3A49ED-6553-4D7E-B933-387951643EABを利用。Simulator一覧確認はsandbox内で失敗したため、許可されたsandbox外実行で端末の存在を確認。
- MyMusic scheme、Debug、CODE_SIGNING_ALLOWED=NO、指定destination、並列無効で対象test実行。TEST SUCCEEDED（buildを含む）。XCTest 31件＋Swift Testing 12件、失敗0。
- 対象: PlaybackBehaviorScoringTests / PlaybackSelectionPolicyTests / TrackPreferencePersistenceTests / TrackPreferenceImportPreviewTests / ExternalBackupServiceTests。負評価の表、+10〜15、範囲外clamp、既存補正、保存・import、旧／現行backup復元を確認。
- git diff --check成功。専用lint設定なし。実機デプロイ・実データ復元・体感上の選曲確認は未実施。
- XCTestDevicesは開始前UUID folderなし、合計12 KiB。終了後も同じ。test端末の作成0、削除0、XCTestDevices削除0。DerivedDataの削除なし。

## 明示依頼によるデプロイ

- git status確認後、check-iphone.shを実行。sandbox内では実機一覧取得timeout、権限付き再実行で成功。Vesperaは実機iPhone 17e、UDID 00008150-000C54280E33401C。
- deploy-iphone.sh成功。MyMusic.xcodeproj／MyMusic scheme／MyMusic product、Debug、maruyama.MyMusic。BUILD SUCCEEDED、Install成功、Launch成功。既存の未コミット変更を含む作業ツリーを使用し、署名・識別子・Team・deployment targetは変更なし。
- このデプロイではtest未実行。test端末作成・削除0。実機での選曲体感は未確認。
