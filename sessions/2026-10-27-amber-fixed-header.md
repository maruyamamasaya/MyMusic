# Amber Loungeと固定背景ヘッダー

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

## 変更

- imagegenスキル／built-in image_genで背景と透過アイコンを個別生成（CLI不使用）。全画像を目視確認。Amber Loungeは琥珀色のガラス光・暗い木目と黒の写真調背景、アイコンはモノトーンの立体的な炎。
- 背景を長辺1800pxのJPEG品質86としてMyMusic/Assets.xcassets/ThemeTextureAmber.imageset/texture.jpg、アイコンを128px alpha PNGとしてThemeIconAmber.imageset/icon.pngへ保存。hasAlpha=yes確認。生成原本は既定生成先に保持。
- AppTheme末尾へamber-loungeを追加し、ThemePalette（accent #F2C078、light #A76A31、surface #17120D）と背景・テーマ切替アイコンに接続。設定と循環は既存allCases経路を使用。既存4テーマの保存IDを維持。再生中Visual Worldは追加せず独立した選択を維持。
- 追加指示によりThemeScreenModifierで黒gradientヘッダーを撤去。ThemeBackgroundの画像構成を共用して、画面のsafe areaを含む同寸法で再描画し、上端領域だけmaskしてoverlay。ナビゲーションバーの標準背景をhiddenにし、その下の固定画像でスクロール内容を遮蔽する。操作はnative toolbarを維持、overlayはhit testing／accessibility対象外。背景の黒20%／Neon色相とaccessibility純黒fallbackも同じ構成を共有する。ぼかしなし。

## 検証

初回テストbuildでprivate compositionのreturn不足を検出し修正。再実行で指定iPhone 17e Simulator向けMyMusicTests/AppThemeTestsの4テスト成功。5テーマ全ての保存復元・未知ID fallback、Visual World独立性、通常／accessibility3のテーマ選択描画を含む。並列test無効、worker1、destination1。iPhone／Watchのコンパイル成功。

XCTestDevicesは前後ともUUIDフォルダなし、合計0 bytes。新規test端末0／削除0、削除作業なし。既存Simulatorを再利用。実アプリ起動とAuroraホームのスクリーンショット（/tmp/mymusic-fixed-texture-header.png）で背景のつながり、タイトル、従来操作の静止表示を確認。スクロール中／Library・Playlistの大見出し縮小／全safe areaや横画面／mini有無でのcrop連続性は未確認。実機未デプロイ。全体テスト未実行。git diff --check成功。

## 生成プロンプト

### background

Use case: stylized-concept. Asset type: full-screen portrait background texture for a dark iPhone music player, portrait 9:19.5. Amber Lounge: a sophisticated abstract photographic atmosphere of a quiet late-night listening room, luminous translucent amber glass and very soft champagne-gold light ribbons, deep warm brown-black shadows, hints of polished walnut grain at the edges, intimate and spacious. Organic subtle optical texture with layered depth, elegant restrained warm light concentrated at edges, dark low-contrast central reading area. No furniture silhouettes, no literal room, no instruments, no sparkles, no stars, no neon blue, no gradients-only flat illustration. Rich fine photographic detail, mostly near black, brightest amber highlights restrained. Edge to edge. No UI, lettering, logos, borders or watermark.

### icon

Use case: stylized-concept. Asset type: tiny iPhone music theme toolbar icon, square. ONE isolated compact sculpted flame silhouette, softly rounded teardrop enclosing a small curved cutout. Monochrome white and silver grayscale only, bold simple shape, satin sculpted highlights, same refined minimal music hardware aesthetic as silver moon and waveform icons. Centered square composition with 12 percent transparent margin, readable at 20px. Genuine transparent alpha background. No panel, no frame, no lettering, no numbers, no color, no cast shadow outside icon.

## 実機デプロイ

ユーザー明示依頼でcheck-iphone.sh成功後deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。Amber、緑Neon、副題先頭文字accent、固定背景ヘッダーを含む現在の未コミット作業ツリーを使用。署名等の設定変更なし。実機の外観・スクロールはユーザー確認待ち。今回デプロイではXCTest追加実行なし、test端末作成0／削除0。
