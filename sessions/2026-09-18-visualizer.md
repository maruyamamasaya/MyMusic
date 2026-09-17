# Waveform・Spectrum・Particle Visualizer

再生中Visual Worldへ独立したVisualizer選択を追加。既存のFFT24帯域に加え、同じ解析窓から48点のPCM波形を要約して表示用frameへ渡す。fluxに対する短いbeat包絡をSimulationへ追加。MetalとCanvasで背景Waveform、主役Spectrum、Particleを描く。音声再生・保存データ契約・署名設定は変更していない。

検証: iOS Debug build、Canvasプレビュー、Mac GPUで実Metal shaderの描画確認、既存iPhone 17e Simulator 1台で関連Unit Test成功、git diff確認。XCTestDevicesにtest端末の作成・削除は各0台で残容量12KB。Vespera（00008150-000C54280E33401C）へのMyMusic Debug実機ビルド・インストール・起動は成功。実際の再生曲での見た目と長時間の熱・電力は手動確認対象。
