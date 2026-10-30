# Weeklyランキング版のVesperaデプロイ

- 明示された実機デプロイ依頼としてMATCH。Git root／git statusを確認し、既存未コミット変更を保持。
- check-iphone.sh成功後にdeploy-iphone.sh実行。
- project: MyMusic.xcodeproj、scheme／product: MyMusic、configuration: Debug。
- Bundle Identifier: maruyama.MyMusic。
- 端末: Vespera、iPhone 17e、UDID: 00008150-000C54280E33401C、paired／Developer Mode enabled。
- Build／Install／Launchすべて成功。Weekly専用画像同梱の現在作業ツリーを導入。
- 署名・Bundle ID・Deployment Target・UI・コードの変更なし。CURRENTと作業記録のみ更新。
- 実機外観・操作はユーザー確認待ち。
- 今回test未実行、test端末作成／削除0台。XCTestDevices合計12K。
- ログ: /tmp/mymusic-weekly-vespera-deploy.log。
