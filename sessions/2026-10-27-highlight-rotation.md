# ハイライト背景4パターン

- Context Guard MATCH、MyMusic Git root一致。imagegenスキルのbuilt-in image_genを使用。
- 生成指示共通：鮮やかで引き込まれるpremium abstract music tile、奥行きのある光る立体、上側に焦点、下側はラベル用の暗い余白、文字・ロゴ・数字・人物なし。
- coral＝fuchsia／orangeの液体ガラスの花、ocean＝turquoise／cyan／cobaltの光へ続く波、violet＝amethyst／roseの結晶とaurora、lime＝chartreuse／emerald／goldの流れるglass sheet。
- Resources/HomeTileImages/highlight-vivid-{coral,ocean,violet,lime}.pngへ保存。旧画像と生成元を保持、既存ルールでGit対象外。
- HomeViewが一時的な画像名を所有しHomeCarouselSection経由でHomeHighlightTileへ渡す。初期ランダム、pull-to-refreshごとに直前を除外してランダム選択、task(id: imageName)で再読込。ライブラリの自動更新や通常の画面再描画では変更しない。timer・永続化・再生への操作なし。画像欠落は既存Artwork fallback。
- 全4枚を目視確認、git diff --check実施。build・test・実tile描画・deploy未実施。テスト端末作成・削除0台、XCTestDevices変更なし。

## 実機デプロイ

- 後続の明示依頼でgit status→check-iphone.sh→deploy-iphone.sh実施、全工程成功。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C、paired／Developer Mode enabled／connected。
- MyMusic.xcodeproj、scheme／product MyMusic、Debug、maruyama.MyMusic。BUILD SUCCEEDED（埋め込みWatch含む）、Install succeeded、Launch succeeded。署名・Team・Deployment Targetの変更なし。
- 生成app内で4種ハイライト＋分析／史／傾向／作業／Rediscoveryの計9PNG存在を確認。build logは/tmp/MyMusic-iPhone-DerivedData/build.log。
- 実機のcrop・pull-to-refresh切替は未操作確認。今回XCTest未実行、テスト端末作成・削除0台、XCTestDevices調査／変更なし。既存の未コミット変更と画像を保持。
