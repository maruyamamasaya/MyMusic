# Weekly装飾版のVesperaデプロイ

- Context MATCH。Git root・git status確認、未コミット変更を保持。
- 明示依頼に従いcheck-iphone.sh成功後にdeploy-iphone.sh実行。
- Project: MyMusic.xcodeproj、scheme／product: MyMusic、configuration: Debug。
- Bundle Identifier: maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID: 00008150-000C54280E33401C、paired／Developer Mode enabled。
- Build／Install／Launchすべて成功。
- Weeklyの説明折りたたみ・1〜10位の段階装飾／カード高さ／間隔と、現在作業ツリーの出力先常時表示等を含む。
- コード／署名／識別子／Deployment Target変更なし。CURRENTと記録のみ更新。
- 実機外観・操作はユーザー確認待ち。
- ログ: /tmp/mymusic-weekly-decoration-vespera-deploy.log。
- 今回test未実行。test端末作成／削除0台、XCTestDevices合計12K。
