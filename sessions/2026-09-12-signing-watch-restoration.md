# Signing・Bundle Identifier・Watch埋め込み復旧

## 事前保全

- 元のiPhone `Vespera` に残る `maruyama.MyMusic` のアプリコンテナを `.xcappdata` として2コピー保存した。
- `playback-history.sqlite3`、WAL、SHMの存在・サイズ・更新日時を確認し、読み取り専用検証で`integrity_check: ok`を確認した。
- Finderの「このMacにバックアップ」と「ローカルのバックアップを暗号化」を有効にし、2026-09-12 16:07の完了表示を確認した。
- iPhone上のMyMusicは削除せず、新しいビルドのInstall／Runも行っていない。

## 復旧

- `MyMusic` Debug／ReleaseのBundle Identifierを`maruyamatomoka.MyMusic`から`maruyama.MyMusic`へ戻した。
- `MyMusic` Debug／ReleaseのDevelopment Teamを`HNCTDS53YZ`から`U29GY347DY`へ戻した。
- 既存の`Embed Watch Content` build phaseと`MyMusicWatch` Target Dependencyを`MyMusic`ターゲットへ再接続した。
- Watch側のBundle Identifier、Development Team、ソース、ターゲット設定は変更していない。
- 音楽史ランキング50位表示を含むアプリ実装には変更を加えていない。

## 検証

- `plutil -lint MyMusic.xcodeproj/project.pbxproj`: OK。
- XcodeのDebug build settingsでiOS Bundle Identifier `maruyama.MyMusic`、Development Team `U29GY347DY`を確認した。
- watchOS SDKで`MyMusicWatch`ターゲットを署名なしbuildし、`BUILD SUCCEEDED`を確認した。
- Generic iOS Device向けに各ターゲット固有SDKを使う署名なし統合buildを実行し、`BUILD SUCCEEDED`を確認した。依存グラフに`MyMusicWatch`が含まれ、`MyMusic.app/Watch/MyMusicWatch.app`へのCopyと`ValidateEmbeddedBinary`が成功した。
- `-sdk iphoneos`を全ターゲットへ強制した初回の代替buildは、WatchターゲットまでiOS SDKで処理され失敗した。ターゲット固有SDKを使う上記統合buildで解消・検証済み。
- 実機へのInstall／Runは行わない。
- 設定復旧のみのためXCTestは実行していない。
