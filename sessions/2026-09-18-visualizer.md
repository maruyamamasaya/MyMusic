# Waveform・Spectrum・Particle Visualizer

再生中Visual Worldへ独立したVisualizer選択を追加。既存のFFT24帯域に加え、同じ解析窓から48点のPCM波形を要約して表示用frameへ渡す。fluxに対する短いbeat包絡をSimulationへ追加。MetalとCanvasで背景Waveform、主役Spectrum、Particleを描く。音声再生・保存データ契約・署名設定は変更していない。

検証: iOS Debug build、Canvasプレビュー、関連Unit Test、git diff確認。実機の見た目と熱・電力は手動確認対象。
