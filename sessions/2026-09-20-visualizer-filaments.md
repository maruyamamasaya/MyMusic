# Visualizerのフィラメント整理

- 24本の等間隔な発光列を撤去。FFT24帯域の値は維持し、3帯域ずつ束ねて8つの非等間隔な光源へ反映する。
- 波形を発生源に、低域は長く太く、高域は短く細い曲線を描く。根元の電離光、白い芯、色付きの外光、短い枝、先端の火花を別々に重ねる。低音量では光源を表示しない。
- MetalとCanvas fallbackの両方を更新。PCM波形、波紋、フォトン、音声解析と設定IDは変更していない。
- iPhone 17e Simulator向けDebug buildと描画用macOSテスト14件が成功。`git diff --check`も成功。実機での印象、熱・電力は未確認。iOS `xcodebuild test`は実行せず、XCTestDevicesの新規作成・削除は0件、残量12KB。
