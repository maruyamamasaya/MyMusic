# ホームの黒い帯の上下をなじませる

Context Guard MATCH。Git rootがMyMusic repositoryであることを確認し、既存の未コミット変更を保持。

ユーザーが実機で良好と確認した再生中の暗幕と同じ方式をHomeSectionBackdropへ適用。見出し・タイル群の裏は黒60%を維持し、上下各16ptだけ透明へ抜けるgradientを背面外側へ追加。既存の全幅・縦padding・section間隔・操作は変更せず、blur／material追加なし。シンプルダークでは従来通り下地なし、透明度低減／高コントラストでは不透明黒を維持。

検証: 指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／埋め込みWatch）。git diff --check成功。実際のスクロール・各テーマの外観は未確認。実機デプロイは今回依頼に含まれないため未実施。

表示のみの変更で構造・データフロー変更なし。ARCHITECTURE更新・ADR追加不要。XCTest未実行、test端末作成0／削除0。XCTestDevices未操作、残容量未計測。
