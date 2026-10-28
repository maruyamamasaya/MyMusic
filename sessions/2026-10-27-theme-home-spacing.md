# ホームのテーマ別余白を統一

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

HomeSectionBackdropでsimpleDark以外にだけ付いていたpadding(.vertical,12)が、各sectionを24pt高くしていた。追加paddingを除去し、見出し・タイル群の元の高さとLazyVStackの既存spacing28へ揃えた。背景の黒60%・全幅・端のfadeとaccessibility fallbackは維持し、レイアウトに高さを加えない。PlaybackMetadataBackdropは全テーマ共通のpaddingでテーマ差の原因ではないため変更なし。

外観のみでXCTest追加なし。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実機未デプロイ。全テーマの実画面比較・大きい文字は未確認。

指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）。git diff --check成功。

## 実機デプロイ

ユーザー依頼でcheck-iphone.sh成功後deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。余白統一と下部背景切り出しを含む未コミット作業ツリーを保持して使用。署名等の設定変更なし。実機外観はユーザー確認待ち。XCTest未実行、test端末作成0／削除0。
