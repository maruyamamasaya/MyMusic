# Rediscovery Mix背景調整

- Context Guard MATCH、MyMusic Git root一致。既存変更は保持。
- imagegenスキルのbuilt-in image_genで既存mix-rediscovery.pngを編集。色味・金属感は保持、中心の結晶球とorb構図を流れる金属ribbonとblue-green glass waveformへ変更。濃紺背景、下側の白タイトル用余白、文字なし。
- 生成画像を目視確認しResources/HomeTileImages/mix-rediscovery-v2.pngへ保存。旧画像と生成元を保持。既存運用によりGit対象外。
- HomeMixTileの参照のみv2へ変更、再生・選曲は変更なし。
- git diff --check実施。build・test・deploy・実機crop確認は未実施。テスト端末作成／削除0台、XCTestDevices調査・変更なし。

## v3調整

- ユーザーの追加指定で全画面を埋めるムーディーな構図へ再編集。built-in image_genへv2を渡し、青緑・sapphire・champagne goldと金属感を保持、画面四辺まで流れる金属の襞とglass曲線、床・地平線・空白なし、控えめな陰影と奥行き、文字なしと指示。
- mix-rediscovery-v3.pngへ保存しHomeMixTileの参照を変更。v1・v2と生成元を保持。既存Git対象外運用。生成画像目視とgit diff --check実施、build・test・deploy未実施。

## v3実機デプロイ

- 明示依頼でgit status→check-iphone.sh成功→deploy-iphone.sh成功。既存未コミット変更を保持した現在の作業ツリーを使用。
- Vespera、model iPhone 17e、UDID 00008150-000C54280E33401C、paired／Developer Mode enabled／connected。
- MyMusic.xcodeproj、scheme／product MyMusic、Debug、Bundle ID maruyama.MyMusic。BUILD SUCCEEDED（Watch含む）、Install succeeded、Launch succeeded。
- app内mix-rediscovery-v3.png存在を確認。build log: /tmp/MyMusic-iPhone-DerivedData/build.log。署名・Team・Deployment Target変更なし。
- 実機cropと描画は未確認。今回XCTest未実行、テスト端末作成／削除0台、XCTestDevices調査・変更なし。
