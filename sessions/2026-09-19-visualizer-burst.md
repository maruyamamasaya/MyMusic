# Visualizerの空間粒子バースト

- 既存の発光PCM48点波形、FFT24帯域バー、漂う微小光子を維持し、fluxで検出したbeatごとに低・中・高域の強さと発生時刻を表示用Simulationに記録した。
- Metal／Canvasで最大0.95秒の飛散を描く。波形、バー先端、左右端、下部を発生点とし、曲seedと発生回数で方向と奥行きを安定させる。低域は大きい粒子と広がるGlow、中域は中粒子、高域は細かい高速粒子。Metalは通常24粒子、低品質12粒子、Canvasは24粒子に制限する。
- Metalの帯域参照を24分割へ合わせ、最後のFFT帯域も参照できるようにした。
- 音声解析tap、再生、保存契約、署名は変更していない。`xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO -quiet build`成功。`./scripts/check-visual-world.sh`は11件成功。
- 実機での音楽に対する見た目、長時間の熱・電力、アクセシビリティは未確認。iOSの`xcodebuild test`は実行せず、XCTestDevicesの端末作成・削除は0件。
