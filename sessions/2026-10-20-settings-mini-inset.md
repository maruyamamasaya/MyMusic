# 設定末尾とミニプレイヤーの重なり

- Context Guard MATCH。Git root MyMusic、main上で作業。前作業の濃さ0.90と文書の未コミット変更を保持。
- 本体iPhone 17e Simulator、合成WAV再生中に設定を最大scrollし、データ管理の行がmini裏に残り、それ以上scrollできない状態を再現。
- RootViewの設定tabだけ、safeAreaInsetをNavigationStack外からSettingsViewへ移動。Listへminiの必要余白が伝わる配置にする。詳細Navigation先にはminiを重ねない。他tab・再生・保存形式の変更なし。
- 修正版の本体Simulatorで同じ再生状態を作り、設定末尾行がminiより上へscrollできることを画像確認。座標tapでデータ管理へ遷移、音楽再生を継続。データ管理内も末尾「設定とプリセット」と説明までscroll表示確認。Import／Exportは実行していない。
- iPhone／Watch generic Simulator Debug BUILD SUCCEEDED。ログ/tmp/mymusic-settings-inset-build.log。git diff --check成功。
- 実機未検証、デプロイ・commit・push未実施。XCTest未実行、test端末作成・削除0台。既存Simulator1台のみ使用、確認後shutdown。XCTestDevices容量計測対象のtest実行なし。DerivedData削除なし。

## 実機デプロイ

- 後続の明示依頼でgit status確認、check-iphone.sh成功後にdeploy-iphone.sh実行。
- MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / maruyama.MyMusic。
- Vespera（00008150-000C54280E33401C）へBuild・Install・Launchすべて成功。ログ/tmp/mymusic-settings-inset-deploy.log。
- 既存の背景係数0.90変更も含む。署名・project設定変更なし。実機での設定操作は未確認。commit・pushなし。XCTest未実行、test端末作成・削除0台。

## 実機確認とmain反映

- ユーザーがVesperaで「データ管理も開けた」と確認。設定入口の実機確認済み。Import／Export操作の確認を意味しない。
- 明示依頼により濃さ0.90変更と本修正、関連文書・記録をmainへコミット・pushする。
