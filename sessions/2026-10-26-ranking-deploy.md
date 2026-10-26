# ホーム・ランキングのVesperaデプロイ

- ユーザーの明示承認により実施。Context Guard MATCH、MyMusic Git root一致。未コミット変更を保持して現在の作業ツリーを使用。
- git status → scripts/check-iphone.sh成功 → scripts/deploy-iphone.shの順。ログを外側でredirectした2回は内部devicectlの15秒timeoutでbuild前停止。redirectなしの同script実行ではcheckからlaunchまで成功。timeoutとredirectの因果は未確定。script修正なし。
- 端末：Vespera、iPhone 17e、UDID 00008150-000C54280E33401C。paired／Developer Mode enabled／tunnel connected。
- Xcode 27.1 (27A9275)、MyMusic.xcodeproj、scheme MyMusic、product MyMusic、Debug、Bundle Identifier maruyama.MyMusic。既存Team U29GY347DYとiOS Deployment Target 26.5を維持。
- 実機Build（埋め込みWatch含む）：BUILD SUCCEEDED。Install：成功。Launch：成功。成果物 /tmp/MyMusic-iPhone-DerivedData/Build/Products/Debug-iphoneos/MyMusic.app、build log /tmp/MyMusic-iPhone-DerivedData/build.log。
- ソース・署名設定・スクリプト変更なし。CURRENTと本記録のみ追記。git diff --check実施。
- XCTest未実行。テスト端末作成・削除0台。XCTestDevicesの容量調査／変更なし。既存アプリdataの削除・初期化なし。
- 実機のランキング部門設定・描画・再生と発掘する24時間除外は未操作確認。テストソースのcompile／実行も未確認。
