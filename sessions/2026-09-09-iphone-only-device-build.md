# iPhone 単体の実機ビルド

## 作業

- `MyMusic` ターゲットの Build Phases から `Embed Watch Content` を外した。
- `MyMusic` ターゲットの Target Dependencies から `MyMusicWatch` を外した。
- `MyMusicWatch` ターゲット、Watch のソース、製品参照、署名設定は削除・変更していない。
- 既存の `MyMusic` Signing / Bundle Identifier 変更と `Info.plist` の未コミット差分は保持した。

## 意図

iPhone 単体の `MyMusic.app` に Watch App を埋め込まず、iPhone の実機ビルド時に Watch バイナリの署名一致検証が発生しない構成にする。

## 検証

- 対象: 実機名 `T`、iPhone 13（iPhone14,5）、UDID `00008110-000E705934F1801E`。
- `xcodebuild clean`: `CLEAN SUCCEEDED`。
- Debug / iphoneos build: `BUILD SUCCEEDED`。依存グラフに `MyMusicWatch` は含まれず、元の埋め込みバイナリ署名エラーも発生しなかった。
- 生成した `MyMusic.app` に `Watch/` directoryが存在しないことを確認した。
- Bundle Identifier `maruyamatomoka.MyMusic` として実機へのInstallに成功した。
- 初回Launchは端末側の開発者プロファイル未信頼により拒否されたが、端末側での信頼後に再確認し、Bundle Identifier `maruyamatomoka.MyMusic` の起動に成功した。
