# 再生画面の評価欄とシークバー間隔

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

通常／作業用／HiRes再生中画面で、曲情報・評価欄とProgressBarViewの間にあった伸縮Spacerを再生操作の下へ移動。余剰高さは最下部で吸収し、シークバーと再生操作を上へ寄せる。VStackの既存18pt間隔、seekと評価処理、黒40%の下地は維持。Store・保存・構造境界に変更なし。

XCTest未実行（配置のみ）。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実機未デプロイ。実画面での間隔・小さい高さ・Dynamic Type大でのfallbackは未確認。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。git diff --check成功。

## 実機デプロイ

ユーザー依頼でcheck-iphone.sh成功後、deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。シークバー位置調整と追加blur完全撤去・黒40%下地の現在作業ツリーを使用。未コミット変更を保持、署名等の設定変更なし。実機の外観と操作はユーザー確認待ち。XCTest未実行、test端末作成0／削除0。
