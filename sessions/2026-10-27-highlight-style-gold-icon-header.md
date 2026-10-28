# チューニング、ハイライト外観、金のピアノアイコン、ヘッダー階層

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

## チューニング

HomeSectionBackdropへcompactFadeを追加しチューニングだけ有効化。上下fadeは16→6pt、負の外側paddingは0へ変更して内容内でフェードさせる。ホーム先頭のtop4ptも0にしてヘッダー直下へ配置。他sectionのfadeと高さは維持。

## ハイライト再生

HighlightPlayerViewの背景をThemeBackgroundへ統一。各pageの拡大Artwork＋54pt blurと暗転gradientを撤去。曲情報＋評価列は既存14pt間隔でまとめ、共通PlaybackMetadataBackdropをverticalPadding0／horizontalOutset20で使用して追加高さなしの黒60%帯へ統一。

丸button／capsuleのultraThinMaterialを撤去。評価ボタンは42ptの従来枠を明示して維持。ハート選択は通常同様red、EQ有効とprogressはtheme accent。Artworkの影を除去。既存のページ順、swipe、Picker、Artworkサイズ、font寸法、操作の順番とaction、解析・queue・再生処理は維持。グレーblurの再追加なし。

## アプリアイコン

添付「クリスタルと黄金のグランドピアノ.png」（1254px正方形、alphaなし）をsipsで上75／左130から1100px正方形にcropし、1024px JPEG品質95へ変換。ピアノ本体を大きく見せた切り出しを目視確認。MyMusic/Assets.xcassets/AppIcon.appiconset/crystal-gold-piano.jpegへ保存し、既存通常／dark／tintedの3枠を同画像へ変更。元画像と以前のiconは保持。Watch・識別子・署名・project設定は変更なし。画像生成なし（ユーザー画像をcrop）。

## ヘッダー

ユーザー報告のLibrary／Playlistの初期大見出し消失は、固定画像overlayがscroll内容側の大見出しまで覆う構成が原因。ThemeScreenModifierの前面overlayを撤去し、ThemeNavigationBackgroundでnative navigation barの背景ShapeStyleとしてImagePaintを渡す。nativeタイトル・操作の階層を維持。

ImageRendererで共通ThemeBackgroundを全画面viewportと同じ寸法・2xで描き、上240ptだけcropして背景へ使用（黒20%・Neon色相も共通）。最新theme／viewportの画像1枚のみcache、毎frameの描画なし。透明度低減／高コントラスト／simpleDark／viewport未取得は黒。操作のhit testingを覆うViewなし。大見出しもnative背景の前面になる。

## 検証

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）、git diff --check成功。crop画像を目視確認。XCTest未実行（表示のみ）、test端末作成0／削除0、XCTestDevices未操作・容量未計測。実機未デプロイ。

ハイライトの実操作・全幅／大きい文字、nativeヘッダーの大見出し初期表示・縮小・スクロール時の画像位置は実画面未確認。アイコン小サイズでの見え方も実機確認待ち。

## 実機デプロイ

ユーザー依頼でcheck-iphone.sh成功後deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusicのBuild・Install・Launchすべて成功。現在の未コミット変更を保持して使用。署名等の設定変更なし。実機でのヘッダータイトル・ハイライト外観／操作・アイコンはユーザー確認待ち。XCTest追加実行なし、test端末作成0／削除0。
