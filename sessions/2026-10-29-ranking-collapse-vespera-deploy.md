# 全期間ランキング説明整理版のVesperaデプロイ

- Context MATCH。Git root・status確認、未コミット変更を保持。
- check-iphone.sh成功後にdeploy-iphone.sh実行。
- Project: MyMusic.xcodeproj、scheme／product: MyMusic、configuration: Debug。
- Bundle Identifier: maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C、paired／Developer Mode enabled。
- Build／Install／Launch成功。全期間ランキング説明折りたたみを含む現在作業ツリーを導入。
- コード／署名／識別子等の変更なし。CURRENTと記録のみ更新。外観・操作は実機確認待ち。
- ログ: /tmp/mymusic-ranking-collapse-vespera-deploy.log。
- 今回test未実行、test端末作成／削除0台。XCTestDevices合計12K。
