# テーマ背景の生成テクスチャ化

Context Guard MATCH、Git root確認済み。既存未コミット変更を保持。

当初Canvasで3テーマを再設計し、実ViewをmacOS ImageRendererで描画確認したが、ユーザーから図形的な見え方を指摘され、画像生成へ変更。試作Canvas変更は元に戻した。

imagegenスキル／built-in image_genで3枚を個別生成。CLI不使用。全画像を目視確認し、sipsで長辺1800px・JPEG品質86へ変換してMyMusic/Assets.xcassets/ThemeTexture{Cosmos,Aurora,Neon}.imageset/texture.jpgへ保存（合計約1MB）。生成原本は既定保存先に保持。

ThemeBackgroundは生成画像と薄い上下の暗幕を表示。シンプルダーク・アクセシビリティの純黒fallback・操作・保存・再生を維持。ThemePaletteの副題のみ追従。センサー／timer／視差なし。アーキテクチャは既存View境界内、画像asset参照だけ追加。

## 生成プロンプト

### cosmos

Use case: stylized-concept. Asset type: full-screen portrait background TEXTURE for a dark iPhone local music player, 9:19.5 portrait composition. Blue Cosmos: a richly detailed photographic Milky Way crossing diagonally from upper right to lower left, thousands of fine irregular stars, dense luminous stellar dust, dark branching dust lanes, subtle midnight blue and muted violet nebulosity. Vast deep black negative space, no planets, no giant stars, no lens flares. Sophisticated cinematic photographic texture, exceptionally fine detail and natural irregularity. Keep overall exposure dark, most pixels near black; the texture must still be perceptible. Brightest details are restrained. Visual interest spans the entire portrait, with darker low contrast central reading area and upper navigation region. Edge to edge, no borders, no UI, no icons, no lettering, no watermarks. This is the actual background image, not a phone mockup.

### aurora

Use case: stylized-concept. Asset type: full-screen portrait background TEXTURE for a dark iPhone local music player, 9:19.5 portrait composition. Living Aurora: photographic abstract polar aurora curtains made of delicately folded flowing light, jade teal and muted violet, fine silky vertical striations, atmospheric depth and graceful organic flowing layers, fading naturally into deep black. No horizon, no landscape, no stars. Sophisticated cinematic photographic texture, exceptionally fine detail and natural irregularity. Keep overall exposure dark, most pixels near black; the texture must still be perceptible. Brightest details are restrained. Visual interest spans the entire portrait, with darker low contrast central reading area and upper navigation region. Edge to edge, no borders, no UI, no icons, no lettering, no watermarks. This is the actual background image, not a phone mockup.

### neon

Use case: stylized-concept. Asset type: full-screen portrait background TEXTURE for a dark iPhone local music player, 9:19.5 portrait composition. Pulse Neon: premium macro photograph of layered smoked optical glass prisms, large asymmetric overlapping translucent glass planes, thin cyan edge refraction and deep cobalt light, subtle real material texture, deep black negative space, refined architectural light installation. No grid, no triangles pattern, no text, no rainbow. Sophisticated cinematic photographic texture, exceptionally fine detail and natural irregularity. Keep overall exposure dark, most pixels near black; the texture must still be perceptible. Brightest details are restrained. Visual interest spans the entire portrait, with darker low contrast central reading area and upper navigation region. Edge to edge, no borders, no UI, no icons, no lettering, no watermarks. This is the actual background image, not a phone mockup.

## 検証と制約

試作Canvas版build成功。生成テクスチャ最終版も指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）。XCTest未実行（外観のみ）、test端末作成0・削除0。XCTestDevices未操作、残容量未計測。実機デプロイ未実施。実アプリの全画面・横画面・大きいDynamic Typeでの可読性、実機のメモリ／スクロール負荷は未確認。生成原画の目視確認は実画面での可読性合格を意味しない。

最終ThemeBackground本体（iOS専用toolbar modifierを除いた同じView）の画像参照だけをmacOSプレビュー用のファイル読込に置換し、393×852pt・2xで全4テーマをImageRenderer出力。Cosmosのcropと暗幕を目視確認。プレビュー用コード・PNGは/tmpのみ。git diff --check成功。

## 実機デプロイとヘッダー案

ユーザーの明示依頼でcheck-iphone.sh成功後、deploy-iphone.shを実行。Vespera（iPhone 17e、UDID 00008150-000C54280E33401C）へMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle Identifier maruyama.MyMusicのBuild・Install・Launchすべて成功。未コミット作業ツリーを保持して使用。署名等の設定変更なし。XCTest未実行、test端末作成0・削除0。

スクロール時の黒ヘッダーはThemeScreenModifierのnavigationBar用黒gradientが原因。ユーザーへ、固定した一枚の背景をヘッダーまでつなぎ、薄いスモークと下端fadeで可読性を保つ方向を提案。今回はヘッダー変更は行っていない。実機での見え方はユーザー確認待ち。
