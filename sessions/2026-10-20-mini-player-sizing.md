# 通常ミニプレイヤーのサイズ調整

- Context Guard MATCH、Git root確認済み。既存の未コミット変更を保持。
- ユーザーのサイズ不一致報告を受け、通常ミニのサイズへ寄せる方針。SceneryBGMOverlayのisMiniPlayer分岐では幅390pt制限と2段fallbackを使用せず、伸縮するtrackCreditと幅確保する操作の1段表示へ変更。
- MiniPlayerView外側の上下padding計8ptを削除。標準文字サイズではパネル高52pt、Dynamic Typeの拡大は維持。時計・電池非表示、車窓側のサイズは維持。
- generic iOS Simulator Debug build（Watch含む）BUILD SUCCEEDED。Swift parse、git diff --check成功。実画面の寸法確認は未実施。
- ユーザーのデプロイ禁止を維持、デプロイせず。XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。
- ホームのテーマボタン消失と車窓起動不具合は未修正・未解決として保持。

## 依頼による実機デプロイ

- 後続のユーザー依頼でデプロイ禁止を解除。git status確認、check-iphone.sh成功後、deploy-iphone.shを実行。
- MyMusic.xcodeproj / MyMusic scheme / Debug / Product MyMusic / maruyama.MyMusic。
- Vespera / UDID 00008150-000C54280E33401C。Build・Install・Launchすべて成功。ログ: /tmp/mymusic-mini-sizing-deploy.log。
- 署名・project設定変更なし。ホームのボタン消失・車窓起動不具合は未修正。ミニサイズの実機確認待ち。
- XCTest未実行、test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。
