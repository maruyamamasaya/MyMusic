# 再生情報のスモークグラス

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

ユーザー依頼で通常／作業用の再生中画面に、曲名・アーティスト・アルバム・再生回数／時間・ハート／あとで聴く・グッド等の評価と操作列を一つにまとめた黒40%＋ultraThinMaterialの背面を追加。HiRes再生中画面にも既存の曲情報・再生回数・ハート欄へ同じmodifierを適用（元々ないグッド列は追加しない）。

PlaybackMetadataBackdropはpadding12・角丸16。外側の横paddingを相殺して元の文字／操作の利用可能幅を保持し、狭い幅で操作列を余分に圧縮しない。文字とボタン自体はぼかさない。Reduce Transparency／increased contrastでは黒100%へ戻す。表示専用でStore・Service・保存・再生操作の変更なし。Artwork・seek・再生操作主列・Visual World・車窓HUDは対象外。

XCTest未実行（外観のみ）。test端末作成0／削除0。XCTestDevices未操作・容量未計測。実機デプロイなし。実画面での配置、Dynamic Type大、各テーマ・操作・material負荷は未確認。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。git diff --check成功。

## 実機デプロイ

ユーザーの明示依頼によりcheck-iphone.sh成功後、deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle Identifier maruyama.MyMusicのBuild・Install・Launchすべて成功。再生情報グラス、ホームとminiの背面ぼかしを含む現在の未コミット作業ツリーを使用。署名等の設定変更なし。実機の外観・操作はユーザー確認待ち。XCTest未実行、test端末作成0／削除0。
