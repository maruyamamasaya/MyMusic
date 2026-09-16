# Visual World — Photon Sphereへ即時変更

- ユーザーの指示により幾何構造を廃止。Metal shaderを単一の立体的な発光球体に置換。
- 内部volume、光の細い流れ、微細な発光粒子、陰影、haloを実装。Canvas fallbackも同じ単一球体へ変更。
- 音声解析・再生・操作・既存の負荷制御は維持。CURRENT、ARCHITECTURE、仕様書、ADRの改訂履歴を更新。
- 汎用iOS Simulator destinationのbuild成功。Mac GPUで実shaderを描画し、球体の構図と発光を目視確認。
- 描画変更のみのためXCTestは未実行。test端末の作成・削除0台。実機デプロイ・熱の計測は未実施。
