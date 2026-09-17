# Visual World — Visualizer

Waveformを背景から中景、24バンドのSpectrum / EQを主役、疎なParticleを雰囲気の層として描く。設定 → デザイン → 再生中のビジュアル、またはアート画面のメニューから選ぶ。選択IDは `visualizer`。

## 音と見た目

- 既存の2048点FFTから低・中・高域と24バンドを取得する。Spectrumの24本は各帯域の平滑化値を直接示し、低・中・高域の総量で対応領域を少し補強する。
- Waveformは同じPCM窓を48区間に分け、左右で振幅が大きい方の符号付きピークを取る。音を再加工せず、解析キューから表示専用の値として渡す。停止時は短く減衰する。
- Beatはスペクトルの正の変化量（flux）を緩い基準値と比較し、短い残光にする。音声経路への制御はしない。
- energyは棒の可動範囲、ambientは波形と粒子の柔らかさ、brightはSpectrumの明度、aggressiveはハイライト、electronicは棒の幅に作用する。Artworkの主色・副色・accentを冷色から暖色へ割り当てる。
- 再生中の既存描画制御を共有し、背景化、Reduce Motion、低電力、thermal状態で更新頻度や描画量を抑える。Metalが使えない場合はCanvasへ切り替える。

現段階ではiPhone実機での長時間の熱・電力と視認性を手動確認する。
