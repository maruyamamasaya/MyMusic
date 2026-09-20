# Visual World refinement — 2026-09-20

## 変更

- Plasma Sparkの主線と枝を細くし、二本の枝も折れながら画面端まで届くようにした。放電の短い寿命と24構図は維持した。
- Visualizerを中央の一本の48点波形、Photon Sphereと共通の微小光子、短い円形波紋へ整理した。低・中・高域で波の周期と振幅を変える。
- 旧Visualizerのフィラメント、複数種の波紋、独立した粒子バースト、幅広の直線Glowを削除した。Canvasの光は細い線をぼかして描く。

## 検証

- `./scripts/check-visual-world.sh`: 14件成功。
- iOS Simulator向け`xcodebuild build`: 成功。
- Canvas実描画を390×844で静穏・低域・中域・高域・Plasmaの5状態として画像化。静穏時に横長の光の帯を確認し、ぼかした細線へ変更して消失を再確認。3帯域の波形の違い、Plasmaの画面端までの枝を確認。
- Metal画像化はこの実行環境で`MTLCreateSystemDefaultDevice()`が`nil`を返したため実施できず。iPhone実機のMetal描画と長時間の熱・電力は未確認。
- `xcodebuild test`は実行せず。XCTestDevicesの新規作成・削除は0件。

## 実機導入

- `./scripts/check-iphone.sh`成功。Vespera（iPhone 17e、UDID `00008150-000C54280E33401C`）はpaired、Developer Mode enabled、tunnel connected。
- `./scripts/deploy-iphone.sh`で`MyMusic.xcodeproj`／`MyMusic` scheme／`MyMusic` product／`maruyama.MyMusic`をDebug実機build。Vesperaへのinstall・launchまで成功。埋め込み`MyMusicWatch.app`もbuild成功。
- Comet（Apple Watch SE、CoreDevice ID `72EDC928-25C2-53C5-BFAC-CA38254ED951`）はpairedと表示されたが、`devicectl device install app`が3回ともCoreDeviceService初期化タイムアウトで失敗。今回のWatch直接導入・起動は未完了。
