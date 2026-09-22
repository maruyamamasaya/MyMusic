# Watch Simulator AppIcon build再発防止

## 作業

- `MyMusicWatch/Assets.xcassets/AppIcon.appiconset`を確認し、iPhone Appと同じ1024×1024の`iconmusic.jpeg`がWatch用universal AppIconとして設定済みであることを確認した。
- `AGENTS.md`と`README.md`の標準Simulator buildを、全targetへiPhone SDKを強制する`-sdk iphonesimulator`から`-destination 'generic/platform=iOS Simulator'`へ変更した。
- AppIcon画像、asset catalog定義、project、署名、Deployment Targetは変更していない。

## 原因

`-sdk iphonesimulator`をscheme buildへ指定すると、埋め込み`MyMusicWatch` targetにもiPhone SDKが適用される。その結果、Watch用として正しく設定されたAppIconが「適用可能なcontentなし」と判定されていた。画像不足ではない。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`
- build logで`MyMusicWatch`が`watchsimulator`、`MyMusic`が`iphonesimulator`としてasset catalogを処理することを確認した。
- 既存のSwift concurrency warning 2件とAppIntents metadata warningは残るが、AppIcon errorは発生しなかった。
- `xcodebuild test`は実行していない。XCTestDevicesの新規作成・削除は0件。
