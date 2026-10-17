# 車窓の電池表示と専用評価UI — 2026-10-18

## 要求と変更
- MyMusic車窓HUD更新としてMATCH。Git root確認、CURRENT／ARCHITECTUREと既存コード調査済み。関連ADRなし。
- NOW PLAYINGと同じ行の右端、タイトル上へ電池アイコン＋％。縮小時も維持。
- Canvasの微小ドットと既存DotGothic16、白青色・不透明度75%。取得不可は--%、VoiceOverへ取得不可を伝える。
- SceneryBatteryServiceにUIDevice操作を隔離。通知更新のみでtimerを使わず、HUD表示／scene activeの間だけ監視し、終了時に既存monitoring状態を復元する。
- SceneryPreferenceControlsを追加し、車窓のみハート／グッドの選択色を白青へ。グッド数値はアイコン横のDotGothic16、演出なし。両者とも既存TrackPreferenceStoreのAPIを使用。
- 評価ボタン領域と電池表示の文字欄を分離。展開最大390pt／縮小270pt、Artworkで戻る・文字tapで縮小展開・進捗と金属ボタンを維持。
- 共通評価部品、音楽／動画再生、永続化、署名設定は変更なし。

## 検証
- iPhone／埋め込みWatch generic Simulator Debug build成功。ログ: /tmp/mymusic-scenery-battery-build.log。
- 実HUDと実電池Indicator／評価ControlsをmacOS ImageRendererで描画。Store・BatteryService・Artworkは一時stub、残量78%・favorite true・評価15で展開／縮小に重なりなしを確認。
- 描画確認画像: /tmp/mymusic-retro-check/battery-preview.png。scene inactiveで静止したサンプルであり、実機残量通知・評価永続化・動画動作の確認ではない。
- git diff --check成功。専用lintなし。アプリのデプロイ／commitは今回未実施。
- 実機で残量更新・background復帰・縮小表示・評価操作・大きい文字の収まりを確認する必要がある。
- XCTest未実行、test端末作成0／削除0、XCTestDevices既存合計12K。Xcode data削除なし。

## Vesperaへのデプロイ
- 明示依頼に基づき実施。開始時の未コミット変更を保持し、アプリ実装の追加変更なし。
- check-iphone.sh成功後、deploy-iphone.sh実行。
- MyMusic.xcodeproj / Scheme MyMusic / Product MyMusic.app / Bundle ID maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C。
- Debug Build / Install / Launchすべて成功。ログ: /tmp/mymusic-scenery-battery-deploy.log。
- 電池表示と縮小時の見え方、青いハート・グッド数値はユーザー実機確認待ち。
- XCTest未実行、test端末作成／削除0台、Xcode data削除なし。

## 充電状態の雷表示とデプロイ
- 明示依頼で充電中の小さな白青いドット雷を追加。展開・縮小とも電池アイコンと％の間へ配置。
- SceneryBatteryServiceにbatteryStateの通知購読とisChargingを追加。charging／fullで表示、unplugged／unknownで非表示。残量通知と同じ購読ライフサイクル、timerなし。
- VoiceOverへ充電中を追加。満充電で電源接続中も雷を維持。
- iPhone／Watch generic Simulator Debug build成功: /tmp/mymusic-scenery-charging-build.log。
- 実HUD＋BatteryIndicatorを一時stubで100%・充電中・favorite true・グッド15として描画確認。展開・縮小の重なりなし。画像: /tmp/mymusic-retro-check/charging-preview.png。
- git statusで既存未コミット変更を確認・保持し、check-iphone.sh成功後にdeploy-iphone.shを実行。
- MyMusic.xcodeproj / MyMusic scheme / MyMusic.app / maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C。Debug Build／Install／Launchすべて成功。
- デプロイログ: /tmp/mymusic-scenery-charging-deploy.log。実機の接続／切断時の雷更新はユーザー確認待ち。
- git diff --check成功。XCTest未実行、test端末作成0／削除0、XCTestDevices合計12K。Xcode data削除なし。

## 実機確認とコミット
- 2026-10-18、ユーザーがVesperaで充電中の雷表示、ケーブルを抜いたときの消灯、縮小中の見え方を問題なしと確認。
- 上記項目を実機確認済みとしてCURRENT.mdへ反映。青いハート／グッド数値の個別操作や残量の経時更新は今回の報告から確認済みと推定しない。
- 電池・充電表示、車窓専用評価UI、設計／デプロイ／確認記録をまとめてコミット対象とする。
- アプリ実装はデプロイ済み版から追加変更なし。既存の成功buildを採用し、文書更新だけのため追加build／XCTestは実行しない。test端末作成0／削除0。
