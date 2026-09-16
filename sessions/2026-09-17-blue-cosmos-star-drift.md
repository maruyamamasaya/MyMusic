# Blue Cosmosの星に緩やかな漂流を追加

- 全体driftに加え、星ごとに独立した位相・速度の小さい楕円状の座標移動を追加。奥ほど遅く小さく、手前ほど移動量を大きくする。
- 元のseedを固定し、移動中に色・サイズ・明滅タイプが変わらない。既存clockを共有し、休止・Reduce Motionに従う。
- Metal／Canvas双方を変更。再生・解析・操作・アーキテクチャ変更なし。
- 汎用iOS Simulator build成功、git diff --check成功。XCTest未実行。test端末作成・削除0台。実機での動きの確認は未実施。
