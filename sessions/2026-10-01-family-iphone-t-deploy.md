# 家族のiPhone Tへ直接デプロイ

- 明示依頼: 接続済みの家族のiPhone `T` へMyMusicを導入する。
- Git rootを確認し、既存の未コミット文書変更を保持。アプリソース、署名設定、Bundle ID、Team、Deployment Targetは変更していない。
- `DEVICE_NAME=T ./scripts/check-iphone.sh` が成功。端末はiPhone 13、UDID `00008110-000E705934F1801E`、paired、Developer Mode enabled、connected。
- `DEVICE_NAME=T ./scripts/deploy-iphone.sh` が成功。
- Project: `MyMusic.xcodeproj`、Scheme/Product: `MyMusic`、Configuration: Debug、Bundle ID: `maruyama.MyMusic`。
- Build: `BUILD SUCCEEDED`。InstallおよびLaunchも成功。
- ログ: `/private/tmp/MyMusic-T-deploy-20261001.log`。既存の `/tmp/MyMusic-iPhone-DerivedData` を利用し、生成物は削除していない。
- XCTestは実行していない。test端末の作成・削除は0台。家族による音源読み込み・再生の操作確認は未実施。
- TestFlightは別経路でBeta審査待ち（ユーザー報告）。直接導入で審査結果を変更していない。
