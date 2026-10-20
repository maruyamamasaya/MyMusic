# Vesperaテストデプロイ試行

- Context Guard: MATCH。Git root確認後、未コミットのUI変更を保持して指定スクリプトを使用。
- check-iphone.shはsandbox内でCoreDevice XPC timeout。権限付き再実行で成功。
- Vespera / iPhone 17e / UDID 00008150-000C54280E33401C、paired、Developer Mode enabled。
- deploy-iphone.shを実行。MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / Bundle Identifier maruyama.MyMusic。
- Build失敗: This scheme builds an embedded Apple Watch app. watchOS 26.5 must be installed in order to run the scheme。
- Install／Launch未実行。署名・Bundle ID・project構成は変更せず、platform downloadも行わない。watchOS platform復元後の再実行が必要。
- ログ: /tmp/mymusic-20261020-deploy.log、/tmp/MyMusic-iPhone-DerivedData/build.log。
- XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。DerivedData削除なし。

## watchOS復元後の再デプロイ

- ユーザーが復元と再デプロイを承認。xcodebuild -downloadPlatform watchOS -buildVersion 26.5 -architectureVariant arm64で約3.96 GBを取得し、26.5（23T570）のインストール成功。空き容量は開始時約315 GiB。
- check-iphone.sh成功後、deploy-iphone.shを再実行。MyMusic.xcodeproj / MyMusic / Debug / MyMusic / maruyama.MyMusic、Vespera / 00008150-000C54280E33401C。
- BUILD SUCCEEDED、Install succeeded、Launch succeeded。今回のUI変更を含む型検証成功。画面の見た目・操作はユーザー実機確認待ち。
- ログ: /tmp/mymusic-watchos-restore.log、/tmp/mymusic-20261020-deploy-restored.log。
- ソース・署名・project設定の追加変更なし。XCTest未実行、test端末作成・削除0台。runtimeの復元のみでtest端末は作成しない。DerivedData削除なし。
