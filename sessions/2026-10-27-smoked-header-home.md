# 背景の減光・ヘッダー・ホーム下地

Context Guard MATCH。Git root確認、既存未コミット変更を保持。

- ThemeBackground: 生成画像の上に黒20%。既存の上下暗幕を置換。画面領域のbackgroundとして固定し、safe area外まで延長する既存構造を使用。
- ThemeScreenModifier: 黒gradientからultraThinMaterialへ変更して常時表示。背景の色味を透かす。simpleDark／Reduce Transparency／increased contrastでは不透明黒。
- HomeSectionBackdrop追加。ホームのチューニング、カテゴリ、作業用、Mix、プレイリスト、ステーションへ黒40%の角丸下地。見出しとタイルの背面に配置し、Artwork自体の前面には重ねない。simpleDarkは元の配置を維持。アクセシビリティ条件では不透明。
- 保存・再生・依存・署名等の変更なし。CURRENT／ARCHITECTURE／Themes文書更新。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）のDebug build成功（iPhone／Watch）。既存端末へ上書きinstall・launch成功、simctl screenshotでAuroraのホームの減光、見出し・タイル下地、ヘッダーの色味を目視確認。スクリーンショットは/tmp/mymusic-smoked-header.png。

CUAはSimulatorをapp名／bundle IDとも解決できず、スクロール操作の検証は未実施。静止画のみの確認。全テーマ・画面・Dynamic Type大・スクロール中の背景固定や境界・実機のmaterial外観と負荷は未確認。実機デプロイ未実施。

XCTest未実行（表示のみ）。test端末の作成0／削除0。XCTestDevices未操作、残容量未計測。Simulatorの既存アプリデータは削除していない。

## 横幅の調整

追加依頼でHomeSectionBackdropの横8pt inset・角丸を外し、最大幅infinityの黒40%の帯へ変更。見出し・カルーセルの既存横paddingとスクロール操作は維持。指定Simulator向けiPhone／Watch Debug build成功、git diff --check成功。今回は画面再確認・XCTest・実機デプロイ未実施。test端末作成0・削除0。

## 実機デプロイ

ユーザーの明示依頼でcheck-iphone.sh成功後、deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle Identifier maruyama.MyMusicのBuild・Install・Launchすべて成功。背景黒20%・スモークヘッダー・ホーム全面幅黒40%の帯を含む現在の未コミット作業ツリーを使用。署名等の設定変更なし。実機の見え方・スクロール中の挙動はユーザー確認待ち。XCTest未実行、test端末作成0／削除0。
