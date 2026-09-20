# Visualizer 空間場の仕上げ

- 既存の未コミット Visualizer Beta を保持し、Metal / Canvas の24帯域を画面下の独立した列から全幅PCM波形を発生源とする上下のフィラメントへ変更した。低域は太く長く、中域は湾曲し、高域は細く短い。
- 48点波形の白い芯、色の膜、Glow、余韻を維持し、音圧でGlow幅と薄い平行線の密度が変わるようにした。
- 微小光子を低中高域別の大きさ・波形への収束・横方向の偏向・速度差で分けた。アタック時には分岐ごとの散乱を与え、短く減衰させる。粒子seedは固定し、毎frameの再抽選をしない。
- 音声経路、解析契約、保存形式、操作UIは変更していない。
- `./scripts/check-visual-world.sh`: 14件成功。Simulator XCTestは実行していないため、XCTestDevicesの新規作成・削除は0件。終了時の残容量は12KB。
- 標準の `-sdk iphonesimulator` build は既存 Watch AppIcon の asset catalog エラーで停止。`-destination 'generic/platform=iOS Simulator'` と一時的な `ASSETCATALOG_COMPILER_APPICON_NAME=` 上書きによる app / Watch build は成功した。設定ファイルは変更していない。Metal 単独の `xcrun metal` はこの Xcode に Metal Toolchain がないため実行不可。
- 未解決: 実音源と実機での視認性、フレーム時間、長時間の熱・電力。

## Vespera 実機デプロイ

- `git status` で既存の未コミット変更を確認し、そのまま保持した。
- `./scripts/check-iphone.sh` 成功後、`./scripts/deploy-iphone.sh` を実行。
- `MyMusic.xcodeproj` / `MyMusic` / `MyMusic`、Bundle ID `maruyama.MyMusic`、Debug 実機 build 成功。
- Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）へ install 成功、launch 成功。WatchアプリはiPhone bundleに埋め込まれたが、Watch実機には今回デプロイしていない。
- 実際の音源を再生した際のVisual Worldの見た目、熱・電力は未確認。Simulator XCTestは実行せず、XCTestDevicesの作成・削除は0件。
