# MyMusic Themes — Beta 1.2

## デザインの意図

参照: [living-aurora-ui](https://github.com/maruyamamasaya/living-aurora-ui)、commit `7138d4a5f8578cc1991c6a3add76fef30c11e345` の `docs/DESIGN_SYSTEM.md` と `docs/themes/`。Webのコードや依存を移植せず、光を面の階層として扱う設計をSwiftUIへ適用した。

| Theme / 保存ID | 世界観 | Base | Surface | Accent | Light | Radius | 光量 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| シンプルダーク / simple-dark | 従来の黒と標準アクセント、装飾なし | #000000 | #1C1C1E | Asset AccentColor | なし | 20pt | 0 |
| Living Aurora / living-aurora | 紫の拡散光とシアンの反射 | #000000 | #101116 | #75E3DE | #9376EE | 22pt | 0.12 |
| Pulse Neon / pulse-neon | 黒い光学面、細い信号線 | #000000 | #0D1114 | #63E6F5 | #4263FF | 12pt | 0.14 |
| Blue Cosmos / blue-cosmos | 紺の奥行き、疎らな星 | #000000 | #0E121A | #A4CCFF | #3F6FBE | 24pt | 0.11 |

原色を増やさず、暗い余白を残す。写真・Artworkの色は保持する。お気に入り、警告、評価、分析カテゴリの意味を持つ色はテーマ色に一律置換しない。本文はiOS標準のprimary／secondaryとDynamic Typeを使用する。明るいaccentを塗った選択タグの文字はbase色にする。

## 所有と変更方法

- `Models/AppTheme.swift`: 保存IDだけを持つ。ID変更は既存設定との互換性を考慮する。
- `Stores/SettingsStore.swift`: 選択の正本。`setTheme`が`appearance.theme`へ保存する。未保存／未知IDはLiving Aurora。
- `Views/Theme/ThemePalette.swift`: 配色・面の角丸・光量・テーマの表示名の唯一の定義。
- `Views/Theme/ThemeBackground.swift`: 背景と`themeScreen`／`themeSurface`。新しい画面はNavigationStack内のコンテンツへ`themeScreen()`を適用する。新しい装飾カードは`themeSurface()`を使う。
- `Views/Theme/ThemeSettingsView.swift`: 設定 → テーマ。カード全体がボタンで、選択済みをチェックとVoiceOverの選択状態で表す。
- `MyMusicApp`: テーマをEnvironmentで注入し、共通tintとdark color schemeを設定する。ViewのIDを変更しないので切替でnavigationや再生Storeを作り直さない。
- `ExternalBackupService`: 許可した設定キーへ追加。既存backupのキー欠落は初期テーマへ戻る。

選択肢の先頭はシンプルダーク。保存済みの選択と未保存／未知IDのLiving Aurora fallbackは維持する。４テーマはOSのライト／ダーク切替には追従しない。Apple Watchの画面、音源、再生、解析JSONの契約にはテーマを追加しない。

## iPhoneの描画予算とアクセシビリティ

背景は同梱した3枚の生成テクスチャをscaledToFillで表示し、画面寸法でclipする。TimelineView、常駐timer、motion sensor、粒子animation、blurは使わない。画像は長辺1800pxのJPEGで、全3枚の圧縮容量は約1MB。表示中の画像はdecode後に数MBを使用し、複数の画面や設定カードでは合計が増える。

`accessibilityReduceTransparency`またはincreased contrastでは装飾背景を外し、不透明baseを残す。面は通常0.94、不透明度低減時1.0。increased contrastの縁は0.65。Reduce Motionでも同じ静的デザインで、テーマ固有の常時animationはない。

画面背景は各Navigation境界で適用し、Listの標準scroll背景を隠す。List行、検索欄、OSのメニュー／アラート／共有画面には標準dark materialを残す。Artwork上の可読性maskと作業用の暗転も維持する。全行への装飾描画は追加しない。

ホームのチューニングボタンは全テーマで同じ描画とし、既存のプリセット色を60%不透明のgradientとして背景が透けるように表示する。選択状態はチェックと輪郭線で示し、外側の発光は使わない。

## 検証と今後の調整

`AppThemeTests`は設定の初期値・全IDの保存復元・未知ID fallback、および幅393pt・内容に応じた高さで４テーマの通常／accessibility3のカード描画を検証する。描画成功だけでは見た目や操作性の合格を意味しない。Simulatorの画像と実画面を確認する。

検証buildでは`-destination 'platform=iOS Simulator,id=EB3A49ED-6553-4D7E-B933-387951643EAB'`を使用する。`-sdk iphonesimulator`の強制は埋め込みWatchにも誤ったSDKが適用され、Watch AppIconエラーになる場合がある。

リリース前に実音源を含むホーム／ライブラリ／検索／プレイリスト／再生／シート、VoiceOver、最大文字サイズ、実機OLEDと周囲光の下で確認する。現段階を「完璧」や完成基準版への昇格とは扱わない。

## 黒背景素材との調和（Beta 1.1）

全テーマのbaseを純黒へ統一。背景光は左上（幅×1.1と高さ×0.55の小さい半径）と右下（幅×0.65）の周辺に限定し、中央に黒い余白を残す。素材自体の黒をscreen blend等で透過させず、アートワークの黒階調と色を保持する。カード面も黒に近い低彩度へ変更。Cosmosの星は主点0.20／小点0.07、Neon線は当初0.10へ抑えた（下記のPulse専用改訂で変更）。シンプルダークでは背景装飾とthemeSurfaceの装飾縁を描かない。テーマ選択カードの選択枠は操作上必要な表示として残す。

## Pulse Neon — Light Sculpture（旧版・下記の現行仕様に置換）

ユーザーのアート方向指定により、Pulseだけ強い明暗差へ改訂。他テーマの値は維持する。シアンの右上レールとエレクトリックブルーの左下レールを非対称に配置し、純黒の中央を空ける。折れ点に白い発光点、線には白い芯を設ける。文字とArtworkには発光を掛けない。

`PulseNeonLighting.swift`が形状と発光幅を所有。レールは画面幅の93%／6.5%に寄せ、halo 30pt × 0.045、bloom 12pt × 0.13、tube 3pt × 0.9、白芯0.8pt × 0.85、発光点半径2.5pt。背景の光量0.38、青#4263FF。面の方向性のある縁はシアン0.85／青0.48へ変更。継続animationや点滅は使わず、重ねたstrokeで静的に発光を表現する。透明度低減／increased contrast時は従来どおり装飾背景を外す。

## Beta 1.1のアート方向（Beta 1.2で置換）

全テーマのbaseは引き続き#000000。シンプルダークは変更しない。

- **Blue Cosmos**: `CosmosStarField`。星数は面積÷1800、45〜240点。固定の整数式で座標を生成し、描画ごとのrandomは使わない。直径0.65／1.1／1.8pt、不透明度0.22／0.43／0.78。17点に１つの明るい星だけ半径3ptのhalo。青白と白の２温度で夜空の奥行きを作る。
- **Pulse Neon**: `PulseNeonLighting`。５列、目安115pt高の段を交互に0.35cellずらし、三角形が詰まったglass fieldを作る。縁0.45pt×0.18、反射面0.018〜0.08。選択的な光の辺だけ0.7pt×最大0.65。旧版の太いレールと白い発光点を廃止。背景光0.14、カード縁シアン0.38／青0.20。
- **Living Aurora**: `AuroraGradientLighting`。紫の楕円gradient最大0.30、シアン0.21＋青0.10、斜めの帯0.10〜0.12を重ね、下方へ透明に消す。共通baseを塗り替えず光の層を上へ重ねる。

３つとも静的描画で点滅や常駐timerはない。透明度低減／increased contrastではすべての背景装飾を外し、純黒へ戻る。

## ナビゲーションヘッダー

`ThemeScreenModifier`で共通navigation barの背景を縦gradientへ統一。上端は黒、不透明度は位置0→1に対して1.0／0.92（35%）／0.45（75%）／0。大見出しが中央タイトルへ収まる標準navigationの背景表示タイミングを維持し、下端を透明にして画面との境界を和らげる。タイトル・戻る操作はシステムのdark schemeを維持する。

## 再生中アート画面の例外

Visual Worldの6種類は設定 → デザイン → 再生中のビジュアルで選択し、画面テーマと独立して保存する。旧Living Aurora由来の設定はPhoton Sphereへ統合する。

各描画の造形、操作、音声入力は[現行Visual World仕様](NowPlayingVisualWorld.md)に集約する。画面テーマの静的背景とは独立し、Metalが利用できない場合はCanvasへ切り替える。

通常のテーマ背景は上記の静的描画を維持する。再生中画面から切り替えるVisual Worldだけは最大30fpsで描く。色はArtworkの代表色と種類ごとのfallback、動きはTrack Featuresと再生音の表示専用値から作る。


## Beta 1.2：生成テクスチャ（2026-10-27）

シンプルダークの表示は維持。3テーマの背景だけをbuilt-in image_genで生成した写真調テクスチャへ置換する。既存のaccent／surface／radius、テーマ保存ID、再生中Visual Worldとの分離は維持。

- Blue Cosmos: ThemeTextureCosmos。右上から左下へ伸びる天の川、微細な星、暗い塵の帯、青紫の星雲。
- Living Aurora: ThemeTextureAurora。青緑と紫のオーロラ、柔らかな光のカーテンと微細な筋。
- Pulse Neon: ThemeTextureNeon。スモークガラスの重なり、シアンの輪郭反射、深いコバルト光。

ThemeBackgroundで画像を中央cropし、上端22%／中央0%／下端18%の黒gradientを重ねる。縦画面を主対象とし、横画面とテーマ選択カードは中央cropになる。Reduce Transparency／increased contrast時は画像を描かず純黒。視差と常時animationは今回追加しない。旧Canvas部品は保存するがThemeBackgroundからは参照しない。生成プロンプト・検証はsessions/2026-10-27-theme-textures.md。


## 背景の減光・スモークヘッダー・ホーム下地（2026-10-27）

生成テクスチャの上には均一な黒20%を重ね、従来の上下だけの暗幕は置換する。背景はScrollViewの内容ではなく画面領域のbackgroundへ固定し、ignoresSafeAreaでnavigation bar背面まで延長する。

ThemeScreenModifierの黒gradientヘッダーはultraThinMaterialへ変更し、常時表示でスクロール開始時の背景切替を避ける。背後の色味をぼかして透かす。シンプルダーク／Reduce Transparency／increased contrastでは不透明黒を維持する。システムがmaterialの実際の明度・ぼかしを決めるため、実機の見え方は要確認。

ホームはHomeSectionBackdropで、チューニング・各カテゴリ・作業用・Mix・プレイリスト・ステーションの見出しとタイル群の背面に黒40%の下地を画面幅いっぱいの帯として敷く。上下12ptの余白を持ち、横inset・角丸を設けず、Artworkやタイル内容の前面には重ねない。シンプルダークは従来配置、Reduce Transparency／increased contrastでは下地を黒100%とする。


ホームの全幅黒40%帯はultraThinMaterialを下に敷き、背後だけをぼかす。通常miniも薄いmaterialと約40〜43%のスモーク面で背面をぼかす。文字・Artwork・操作の前面へblurは適用しない。mini独立領域にもテーマ背景を配置するが、各画面との画像crop連続性は未保証。ハイレゾminiはmaterial＋黒40%。アクセシビリティ条件では不透明へ戻す。


## 弱いぼかしへの調整とヘッダー復元（2026-10-27）

直前のフル強度materialはユーザー指示で廃止。ホームの黒40%全幅帯、mini、再生情報欄はSubtleBackdropBlur（UIVisualEffectView、systemUltraThinMaterialDark、animator進行8%で静止）へ置換し、黒の下地を維持。ナビゲーションヘッダーは以前の黒gradientと標準の表示タイミングへ戻し、ガラス素材と常時表示指定を撤去。過去節のmaterialヘッダー・full materialの記述を本節で置換する。


2026-10-27 最終訂正: 今回追加したmaterial／SubtleBackdropBlurはすべて撤去し、弱いblurの記述は過去仕様とする。ホームの見出し・タイル群、および再生中の曲情報・評価欄は左右いっぱい・角丸なしの黒40%下地だけ。通常miniはblur追加前のスモーク係数0.90へ復元し、blur用のBottomPlayerLayout背景も撤去。HiRes miniは黒40%のみ。ヘッダーは従来の黒gradient、背景全体は黒20%を維持。詳細はsessions/2026-10-27-black-only-backing.md。

2026-10-27: 黒下地の濃さをユーザー指示で40%→60%へ調整。ホームの見出し／タイル群・再生中曲情報／評価欄・HiRes miniに適用。ぼかしなしと全幅帯の仕様は維持。

追記: miniは60%化の対象外。通常miniは既存の透明度、HiRes miniは黒40%を維持する。


2026-10-27: Pulse Neonのaccentは#7FFFA6、lightは#19B879。背景textureにだけhueRotation -65度を適用し緑へ寄せる。ホームsection副題はHomeSectionSubtitleで先頭1書記素のみテーマaccent、残りsecondaryを使う。新テーマはまだ追加していない。


## Amber Loungeと固定背景ヘッダー（2026-10-27）

5番目にAmber Lounge（amber-lounge）を追加。黒と琥珀色の生成テクスチャ、モノトーン透過の炎アイコン。accent #F2C078、light #A76A31、surface #17120D、radius22。設定／ホームの循環・既存backup許可キーの保存文字列をそのまま使用し、既存4IDを変更しない。

ヘッダーは従来黒gradientを置換。背景と同じ画像・倍率・配置・黒20%・Neon色相を使い、safe areaを含む画面寸法で描画して上端領域だけmaskした固定overlayを表示する。scroll内容はその背後、nativeのタイトル／操作はその前面。blurなし。透明度低減／高コントラスト時は同じ構成で純黒。スクロール時や大見出し縮小時の全画面確認は今後必要。


訂正: ホームの先頭文字accentはサブタイトルではなくsectionタイトルへ適用する（HomeSectionTitle）。チューニングは除外、副題は従来のsecondaryへ戻す。


2026-10-27: 全画面の背景source矩形をThemeViewportModifierで共有。header・各画面・mini領域・tab barの背面は同じ全画面倍率の画像をglobal位置に応じて切り出し、個別領域ごとの拡大を避ける。mini自体の透明度と既存領域分離は維持。


2026-10-27: HomeSectionBackdropの非simpleDark限定の上下12ptを撤去。背景レイヤーは高さを増やさず、全テーマで同じsection内容高・既存spacing28を使用。黒60%と端fadeは維持。


2026-10-27: 大見出しを覆っていた固定背景overlayを廃止。全画面背景の上端をImageRendererで切り出しnative navigation bar背景にImagePaintで配置する。nativeタイトル・操作の前面階層を維持。チューニングだけfade6ptを内容内に収め、他sectionは維持。ハイライト再生もtheme背景＋黒60%情報帯へ統一、materialボタン背景は撤去。詳細はsessions/2026-10-27-highlight-style-gold-icon-header.md。


2026-10-27: 墨和紙（sumi-washi）を6番目に追加。黒い和紙のThemeTextureSumi（saturation0）、透過ThemeIconSumi、accent #D8D8D8／light #8D8D8D／surface #141414／radius20。フォントは既存を維持。既存の全画面共通背景、header、下部背景、選択保存の経路を共用する。


2026-10-27: 黎明（reimei）を7番目に追加。ThemeTextureReimei／ThemeIconReimei、accent #E7B5A4／light #8F94AD／surface #12141A。ThemeTypographyは黎明の見出し・曲名だけHiraMinProN-W3（未提供時system serif）へ変更し、relative text styleでDynamic Typeへ追従。他themeと本文・操作は従来書体を維持。


2026-10-27: ThemeTypographyの墨和紙は同梱した青柳隷書しも（aoyagireisyo2）、黎明はHiraMinProN-W6優先の太字明朝へ変更。標準bold serifまでfallbackするのは黎明。隷書は使用方法・解説をOTFと同梱しUIAppFontsへ登録。見出しと曲名以外は従来書体。詳細はsessions/2026-10-27-japanese-theme-fonts.md。
