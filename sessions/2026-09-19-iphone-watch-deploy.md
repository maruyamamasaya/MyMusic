# Vespera / Comet 実機デプロイ

- `git status`を確認し、未コミットのVisualizer／Plasma Spark変更を保持した。`./scripts/check-iphone.sh`はVesperaのpaired、Developer Mode enabled、tunnel connectedを確認した。続いて`./scripts/deploy-iphone.sh`を実行。
- Project `MyMusic.xcodeproj`、scheme `MyMusic`、configuration `Debug`、product `MyMusic.app`、Bundle ID `maruyama.MyMusic`、Team `U29GY347DY`、iOS deployment target `26.5`。Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）向けbuild、install成功。最初のlaunchは端末ロックで拒否されたが、解除後の再試行で成功。
- 同じbuild内の`MyMusic.app/Watch/MyMusicWatch.app`はXcodeのembedded binary validationを通過。Bundle ID `maruyama.MyMusic.watchkitapp`、companion ID `maruyama.MyMusic`。Comet（Apple Watch SE、UDID `00008301-F09F44180298202E`）への直接installは最初のネットワークトンネル確立がtimeout、再試行でinstallとlaunchが成功。
- Watch画面とiPhoneとの実機通信・操作は未確認。ソース・署名設定は変更せず、デプロイ結果の文書だけ更新した。`xcodebuild test`は実行せず、XCTestDevicesのtest端末作成・削除は0件。
