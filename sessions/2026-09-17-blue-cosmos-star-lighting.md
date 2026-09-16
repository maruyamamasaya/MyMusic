# Blue Cosmosの星を微細化・配色・発光分離

- 星のcoreとhaloを縮小。サイズ・色・発光タイプの乱数を分離。
- 常時点灯45%、瞬き35%、個別パルス20%。音への反応は変動する星に限定。
- Artwork主色／副色／accentと占有率を使用し、青・赤・少数の白い星を混在。Canvasも対応。
- 再生・解析・球体・Pulse Neon・永続化・アーキテクチャに変更なし。
- 汎用iOS Simulator build成功、Mac GPUで描画を目視確認、git diff --check成功。
- XCTest未実行。test端末作成・削除0台。実機・長時間確認は未実施。
- 合成入力preview: /tmp/mymusic-stars-refined.png。
