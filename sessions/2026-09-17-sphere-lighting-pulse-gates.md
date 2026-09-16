# 固定球体の周辺光とPulse Neonゲート

- 球体を短辺90%へ拡大。音量による半径変更と衝撃による回転を停止。内部粒子の生成方式は維持。
- Artwork主色／副色／accentから球体周辺のgradient haloを増強。
- Pulse Neonは交差する蛍光チューブのゲートと前進する透視表現へ変更。Blue Cosmosは夜空を維持。
- Metal／Canvas両方を更新。再生Service・解析・操作・永続化に変更なし。
- 汎用iOS Simulator destination build: BUILD SUCCEEDED。Mac GPUの実shaderで球体／ゲートを描画して目視。git diff --check成功。
- 今回XCTestは未実行。test端末作成・削除0台。実機での見た目・熱評価は未実施。
- preview: /tmp/mymusic-sphere-lighting.png、/tmp/mymusic-pulse-gates.png（合成入力）。
