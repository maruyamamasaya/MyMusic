# MyMusic Themes — Beta 1.1

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

背景は２つのRadialGradient、Blue Cosmosの面積に応じた星のCanvas、Pulse Neonの三角ガラス面Canvas、Auroraの重ねgradient。ランダム生成、TimelineView、常駐timer、粒子animation、blur、画像assetは使わない。Webのhover／pointer／meteorを持ち込まない静的mobile構成とする。

`accessibilityReduceTransparency`またはincreased contrastでは装飾背景を外し、不透明baseを残す。面は通常0.94、不透明度低減時1.0。increased contrastの縁は0.65。Reduce Motionでも同じ静的デザインで、テーマ固有の常時animationはない。

画面背景は各Navigation境界で適用し、Listの標準scroll背景を隠す。List行、検索欄、OSのメニュー／アラート／共有画面には標準dark materialを残す。Artwork上の可読性maskと作業用の暗転も維持する。全行への装飾描画は追加しない。

ホームのチューニングボタンは全テーマで同じ描画とし、既存のプリセット色を60%不透明のgradientとして背景が透けるように表示する。選択状態はチェックと輪郭線で示し、外側の発光は使わない。

## 検証と今後の調整

`AppThemeTests`は設定の初期値・全IDの保存復元・未知ID fallback、および幅393pt・内容に応じた高さで４テーマの通常／accessibility3のカード描画を検証する。描画成功だけでは見た目や操作性の合格を意味しない。Simulatorの画像と実画面を確認する。

検証buildでは`-destination 'generic/platform=iOS Simulator'`を使用する。`-sdk iphonesimulator`の強制は埋め込みWatchにも誤ったSDKが適用され、Watch AppIconエラーになる場合がある。

リリース前に実音源を含むホーム／ライブラリ／検索／プレイリスト／再生／シート、VoiceOver、最大文字サイズ、実機OLEDと周囲光の下で確認する。現段階を「完璧」や完成基準版への昇格とは扱わない。

## 黒背景素材との調和（Beta 1.1）

全テーマのbaseを純黒へ統一。背景光は左上（幅×1.1と高さ×0.55の小さい半径）と右下（幅×0.65）の周辺に限定し、中央に黒い余白を残す。素材自体の黒をscreen blend等で透過させず、アートワークの黒階調と色を保持する。カード面も黒に近い低彩度へ変更。Cosmosの星は主点0.20／小点0.07、Neon線は当初0.10へ抑えた（下記のPulse専用改訂で変更）。シンプルダークでは背景装飾とthemeSurfaceの装飾縁を描かない。テーマ選択カードの選択枠は操作上必要な表示として残す。

## Pulse Neon — Light Sculpture（旧版・下記の現行仕様に置換）

ユーザーのアート方向指定により、Pulseだけ強い明暗差へ改訂。他テーマの値は維持する。シアンの右上レールとエレクトリックブルーの左下レールを非対称に配置し、純黒の中央を空ける。折れ点に白い発光点、線には白い芯を設ける。文字とArtworkには発光を掛けない。

`PulseNeonLighting.swift`が形状と発光幅を所有。レールは画面幅の93%／6.5%に寄せ、halo 30pt × 0.045、bloom 12pt × 0.13、tube 3pt × 0.9、白芯0.8pt × 0.85、発光点半径2.5pt。背景の光量0.38、青#4263FF。面の方向性のある縁はシアン0.85／青0.48へ変更。継続animationや点滅は使わず、重ねたstrokeで静的に発光を表現する。透明度低減／increased contrast時は従来どおり装飾背景を外す。

## 現行アート方向：夜空／幾何学ガラス／Aurora gradient

全テーマのbaseは引き続き#000000。シンプルダークは変更しない。

- **Blue Cosmos**: `CosmosStarField`。星数は面積÷1800、45〜240点。固定の整数式で座標を生成し、描画ごとのrandomは使わない。直径0.65／1.1／1.8pt、不透明度0.22／0.43／0.78。17点に１つの明るい星だけ半径3ptのhalo。青白と白の２温度で夜空の奥行きを作る。
- **Pulse Neon**: `PulseNeonLighting`。５列、目安115pt高の段を交互に0.35cellずらし、三角形が詰まったglass fieldを作る。縁0.45pt×0.18、反射面0.018〜0.08。選択的な光の辺だけ0.7pt×最大0.65。旧版の太いレールと白い発光点を廃止。背景光0.14、カード縁シアン0.38／青0.20。
- **Living Aurora**: `AuroraGradientLighting`。紫の楕円gradient最大0.30、シアン0.21＋青0.10、斜めの帯0.10〜0.12を重ね、下方へ透明に消す。共通baseを塗り替えず光の層を上へ重ねる。

３つとも静的描画で点滅や常駐timerはない。透明度低減／increased contrastではすべての背景装飾を外し、純黒へ戻る。

## ナビゲーションヘッダー

`ThemeScreenModifier`で共通navigation barの背景を縦gradientへ統一。上端は黒、不透明度は位置0→1に対して1.0／0.92（35%）／0.45（75%）／0。大見出しが中央タイトルへ収まる標準navigationの背景表示タイミングを維持し、下端を透明にして画面との境界を和らげる。タイトル・戻る操作はシステムのdark schemeを維持する。

## 再生中アート画面の例外

Visual Worldの5種類は設定 → デザイン → 再生中のビジュアルで選択し、画面テーマと独立して保存する。旧Living Aurora由来の設定はPhoton Sphereへ統合する。

「薄明」は画面の約8割を青い夜空にして、下側に暖色の地平線と速度の異なる雲を描く。Blue Cosmosと同じ方式の星を約7〜8割の密度と控えめな輝度で散らす。曲のenergyと再生音で雲の速度、空の暖かさ、地平線の光量が変わる。Photon Sphereは固定外形のまま内部の光を強め、外側に微小な光子と衛星球を滑らかに不規則な経路で動かす。Plasma Sparkは暗い空間に蛇行する3色の電流、走る電荷、流れる火花を重ねる。Pulse Neonは5種類のゲート形状を通過ごとに切り替え、発光が音へ応答する。VisualizerはPCM由来Waveform、FFT24帯域Spectrum、Particleを3層に重ね、曲の特徴量・音域・beatで形と光を変える。Pulse Neonは5種類のゲート形状を通過ごとに切り替え、発光が音へ応答する。Blue Cosmosは星雲と瞬く星が音へより強く応答する。常時点灯の星は音で一斉に点滅させない。Metalが利用できない場合はCanvasで各表現を描く。

通常のテーマ背景は上記の静的描画を維持する。再生中画面から切り替えるVisual Worldだけは最大30fpsで描く。色はArtworkの代表色と種類ごとのfallback、動きはTrack Featuresと再生音の表示専用値から作る。現行の描画は[Photon Sphere](NowPlayingVisualWorld-PhotonSphere.md)、操作は`NowPlayingVisualWorldView`を参照。
