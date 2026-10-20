# ミニ外枠とホーム操作の表示修正

- MATCH、Git root確認済み。未コミット変更保持。
- 実SceneryBGMOverlayとサンプルStoreを使う/tmpの一時Simulator appで、標準tabViewBottomAccessoryがパネルの上下をcapsule状にclipし、両端だけ縦線が残ることを再現。
- RootViewの通常miniを各tabのsafeAreaInsetへ移動。HiRes専用accessoryは維持。標準高52→64pt、外padding横12／縦4。全周の金属枠を通常mini自身の枠として描く。車窓HUDの寸法は維持。
- HomeViewのテーマ／車窓ボタンは見出し直下のtop safeAreaInset行へ移動。toolbarの右側集計と幅を競合させない。消失原因の単独特定は未完了だが配置を修正し、本体appで両ボタン表示を確認。
- 検証: 既存iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）1台だけ使用。新規Simulator作成なし。実パネル＋サンプルStoreで変更前後の画像確認（/tmp/mymusic-before-frame.png、/tmp/mymusic-after-frame.png）。本体Simulatorでホーム操作行の表示確認（/tmp/mymusic-home-controls.png）。本体のSimulator libraryは空で車窓ボタン無効のため、実データの再生中／停止／一時停止の起動フローは未検証。
- iPhone／Watch generic Simulator Debug BUILD SUCCEEDED。ログ/tmp/mymusic-frame-fix-build.log。git diff --check成功。
- Vesperaへ未デプロイ。XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。DerivedData削除なし。

## Vesperaへのデプロイ

- 後続の明示依頼によりgit status確認、check-iphone.sh成功後にdeploy-iphone.sh実行。
- MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / Bundle ID maruyama.MyMusic。
- Vespera（00008150-000C54280E33401C）へBuild・Install・Launchすべて成功。ログ/tmp/mymusic-frame-home-deploy.log。
- project・署名設定変更なし。実機の見た目と車窓起動の操作確認は未実施。XCTest未実行、test端末作成・削除0台。
