# Track Visual Profile Beta

- 既存のTrack Feature、音響解析、Metal／Canvas描画、再生時seedの依存を確認した。
- Track Featureを描画専用の連続値へ写す`TrackVisualProfile`を追加。画面で曲変更時に目標値を更新し、描画中は指数補間する。低域／高域はTrack Featureに実測値がないため弱い傾向とし、瞬間値は音響解析を使う。
- 6種のVisual Worldへ速度、密度、光、形、Plasma Sparkの発生率の固有係数を追加した。粒子数と既存の描画品質段階は有界のまま。
- 再生ごとに変わっていたseedを曲IDの安定hashへ変更し、星配置とイベント順序にも反映。永続化契約と音声経路は変更しない。
- `xcodebuild -destination 'generic/platform=iOS Simulator' ... build` 成功。既定の`-sdk iphonesimulator`指定はWatch App icon assetで失敗した。ProfileとseedのXCTestを追加したが、Simulator testは実行していない。
- 未確認：実曲での6種比較、seed由来配置の完全なクロスフェード、長時間の熱・電力。
