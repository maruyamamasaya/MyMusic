# Weekly改訂版のVesperaデプロイ

- 明示依頼、Context MATCH。Git root／git status確認。未コミット変更を保持。
- check-iphone.sh成功後にdeploy-iphone.sh実行。
- Project: MyMusic.xcodeproj、scheme／product: MyMusic、configuration: Debug。
- Bundle Identifier: maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C。paired、Developer Mode enabled。
- Build／Install／Launchすべて成功。
- Weeklyの横長共通カード1列、20組ずつ表示、前週比、回数50％・時間30％・日数20％、日本語期間を含む現在作業ツリーを導入。
- コード・署名・識別子・Deployment Target変更なし。CURRENTと作業記録のみ更新。
- 実機外観・操作はユーザー確認待ち。ログ: /tmp/mymusic-weekly-rows-vespera-deploy.log。
- 今回test未実行、test端末作成／削除0台。XCTestDevices合計12K。
