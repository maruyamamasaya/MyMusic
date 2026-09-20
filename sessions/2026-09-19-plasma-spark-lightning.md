# Plasma Sparkの瞬間放電

- 常時走る3本の電流と定常的な火花を撤去し、Visual World Simulationのピーク時刻・低中高域強度・発生回数を用いた一本の短命な放電へ変更した。
- Metal／Canvasとも曲seedと発生回数で経路の位置、向き、長さ、折れ方を変える。白熱した芯、紫・シアン・ローズの電離光、少数の電荷粒子を描く。低域は長く太い放電と短い背景フラッシュ、中域は控えめな蛇行、高域は細い短い放電と枝を担う。0.085秒程度で経路を走り、0.68秒以内に消える。
- 既存の音声解析と表示用Simulationの状態を再利用。再生経路、保存ID、JSON契約、署名は変更なし。
- iOS Simulator Debug build成功。`./scripts/check-visual-world.sh`は11件成功。`git diff --check`成功。実機での見た目、長時間の熱・電力は未確認。iOS `xcodebuild test`は実行せず、XCTestDevicesの新規作成・削除は0件。

## 端から端までの固定20構図

- 既存の短いノイズ経路を、左右・上下・対角で対辺に届く20個の設計済みテンプレートへ置き換えた。放電回数による互いに素な巡回で20種類を全て使い、中域は折れ幅のみを小さく変える。
- MetalとCanvasは同じ9頂点を使う。低域は太さ、高域は細さと短い枝に反映し、主線の到達距離は音域に依存させない。閃光の走行と消光を短縮した。
- 描画用のmacOSテスト13件成功。全テンプレートの端点・個性・巡回を確認した。`-sdk iphonesimulator`の通常buildはWatch `AppIcon` アセットで停止したが、既存iPhone 17e Simulatorをdestinationに指定したDebug buildは成功。`git diff --check`成功。実機での明滅、熱・電力、発光の見た目は未確認。iOS `xcodebuild test`は実行せず、XCTestDevicesの新規作成・削除は0件、残量12KB。`-target`を指定した検証でrepository内に`build/`（約5.1MB）が生成されたため、Xcode dataの削除承認ルールに従い保持した。
