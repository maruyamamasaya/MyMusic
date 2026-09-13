# Vespera / Comet 実機デプロイ調査

- Context Guard: MATCH。Git root確認、既存の未コミットshuffle変更を保持。
- Project: MyMusic.xcodeproj。Scheme: MyMusic。Products: MyMusic.app / MyMusicWatch.app。
- Bundle IDs: maruyama.MyMusic / maruyama.MyMusic.watchkitapp。Team: U29GY347DY。署名・Bundle ID・Deployment Target・App Icon設定は変更していない。
- Vespera: iPhone 17e、UDID 00008150-000C54280E33401C、iOS 26.6.2。DEVICE_NAME=Vespera ./scripts/check-iphone.sh成功。wired / connected / paired / Developer Mode enabled。
- Comet: Apple Watch SE、UDID 00008301-F09F44180298202E、watchOS 26.6。paired / Developer Mode enabledだがtunnel disconnected、ddiServicesAvailable false。device info detailsは20秒でtimeout。

## 修正と結果

- scripts/deploy-iphone.shの-sdk iphoneos強制を除去。WatchまでiOS SDKになる既知のビルド問題を修正。
- -allowProvisioningUpdatesを追加し、既存Automatic signingのprofile取得・更新を許可。
- DEVICE_NAME=Vespera ./scripts/deploy-iphone.shを実行。最初はWatch profile不足、profile更新許可後はNo Accountsとmaruyama.MyMusic.watchkitappのprofile不足でBUILD FAILED。
- Build: 署名で失敗。Install / Launch: Vespera、Cometとも未実施。端末の既存アプリ・データは変更していない。
- ログ: /tmp/mymusic-vespera-deploy.log、/tmp/MyMusic-iPhone-DerivedData/build.log。
- bash -n scripts/check-iphone.sh scripts/deploy-iphone.shとgit diff --check成功。
- Simulator / XCTest未実行、test端末作成0・削除0。DerivedData削除なし。

## 再開条件

Xcodeで既存Team U29GY347DYのApple Accountを利用可能にし、CometをMacから到達可能にする。check成功後に同スクリプトを再実行し、iPhoneへinstall / launch。その後Cometの接続・署名を確認して同buildのWatch appをinstall / launchし、両端末でshuffle操作を確認する。
