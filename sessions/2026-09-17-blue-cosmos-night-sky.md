# Blue Cosmos — 夜空パターン

- ユーザーの早期構築・最小検証の指示に合わせ、Blue Cosmosだけを夜空へ変更。他テーマの球体、音声解析、操作は維持。
- Metal: 青い暗部、淡い星雲、最大3層の星、音域による発光、緩い視差。低品質2層。Canvasにも星空fallbackを追加。
- 汎用iOS Simulator destinationでBUILD SUCCEEDED。Mac GPUで夜空を描画し目視確認。git diff --check成功。
- XCTestは未実行。test端末作成・削除0台。実機デプロイ・発熱検証は未実施。
- 確認画像: /tmp/mymusic-blue-cosmos-night-sky.png（合成入力、UIなし）。
