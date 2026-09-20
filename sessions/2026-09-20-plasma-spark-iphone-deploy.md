# Plasma Spark更新版のVesperaデプロイ

- 未コミットのVisualizer／Plasma Spark変更を保持したまま、`git status`を記録した。
- `./scripts/check-iphone.sh`でVespera（iPhone 17e、UDID `00008150-000C54280E33401C`）のpaired、Developer Mode enabled、tunnel connectedを確認した。
- `./scripts/deploy-iphone.sh`で`MyMusic.xcodeproj`／`MyMusic` scheme／Debugを実機向けbuild。product `MyMusic`、Bundle Identifier `maruyama.MyMusic`、Development Team `U29GY347DY`、iOS Deployment Target 26.5。Build、install、launchすべて成功した。
- デプロイ後の`git diff --check`成功。既存の未コミット変更は保持した。実音源でのPlasma Sparkの見え方は引き続き手動確認が必要。iOS testは実行しておらず、XCTestDevicesの新規作成・削除は0件、残量12KB。
