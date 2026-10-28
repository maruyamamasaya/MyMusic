# ライブラリ画像更新版の実機デプロイ試行

- ユーザーの明示依頼によりVesperaへのデプロイを試行。Context Guard MATCH、Git rootがMyMusicと一致することとgit statusを確認。未コミット変更を保持。
- ./scripts/check-iphone.shを実行。Xcode 27.1 / Build 27A9275は確認できたが、xcrun devicectl list devicesが15秒timeoutで失敗し、対象名・UDID・接続状態を確認できなかった。
- AGENTS.mdの手順に従い、チェック失敗後はdeploy-iphone.shを実行しない。今回Build／Install／Launchすべて未実行。前のデプロイ成功は今回の5枚更新版の反映を意味しない。
- 実行環境からのCoreDeviceアクセスと、iPhoneの接続・ロック解除・信頼状態の確認が必要。端末・署名・project設定・アプリデータ変更なし。
- XCTest未実行、test端末作成0／削除0、XCTestDevices容量未計測。
