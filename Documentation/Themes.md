# MyMusic Themes — Beta 1.1

## デザインの意図

参照: [living-aurora-ui](https://github.com/maruyamamasaya/living-aurora-ui)、commit `7138d4a5f8578cc1991c6a3add76fef30c11e345` の `docs/DESIGN_SYSTEM.md` と `docs/themes/`。Webのコードや依存を移植せず、光を面の階層として扱う設計をSwiftUIへ適用した。

| Theme / 保存ID | 世界観 | Base | Surface | Accent | Light | Radius | 光量 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| シンプルダーク / simple-dark | 従来の黒と標準アクセント、装飾なし | #000000 | #1C1C1E | Asset AccentColor | なし | 20pt | 0 |
| Living Aurora / living-aurora | 紫の拡散光とシアンの反射 | #000000 | #101116 | #75E3DE | #9376EE | 22pt | 0.12 |
| Pulse Neon / pulse-neon | 黒い光学面、細い信号線 | #000000 | #0D1114 | #63E6F5 | #4263FF | 12pt | 0.38 |
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

背景は２つのRadialGradient、Blue Cosmosのみ固定32点のCanvas、Pulse Neonのみ２本の発光レール。ランダム生成、TimelineView、常駐timer、粒子animation、blur、画像assetは使わない。Webのhover／pointer／meteorを持ち込まない静的mobile構成とする。

`accessibilityReduceTransparency`またはincreased contrastでは装飾背景を外し、不透明baseを残す。面は通常0.94、不透明度低減時1.0。increased contrastの縁は0.65。Reduce Motionでも同じ静的デザインで、テーマ固有の常時animationはない。

画面背景は各Navigation境界で適用し、Listの標準scroll背景を隠す。List行、検索欄、OSのメニュー／アラート／共有画面には標準dark materialを残す。Artwork上の可読性maskと作業用の暗転も維持する。全行への装飾描画は追加しない。

## 検証と今後の調整

`AppThemeTests`は設定の初期値・全IDの保存復元・未知ID fallback、および幅393pt・内容に応じた高さで４テーマの通常／accessibility3のカード描画を検証する。描画成功だけでは見た目や操作性の合格を意味しない。Simulatorの画像と実画面を確認する。

検証buildでは`-destination 'generic/platform=iOS Simulator'`を使用する。`-sdk iphonesimulator`の強制は埋め込みWatchにも誤ったSDKが適用され、Watch AppIconエラーになる場合がある。

リリース前に実音源を含むホーム／ライブラリ／検索／プレイリスト／再生／シート、VoiceOver、最大文字サイズ、実機OLEDと周囲光の下で確認する。現段階を「完璧」や完成基準版への昇格とは扱わない。

## 黒背景素材との調和（Beta 1.1）

全テーマのbaseを純黒へ統一。背景光は左上（幅×1.1と高さ×0.55の小さい半径）と右下（幅×0.65）の周辺に限定し、中央に黒い余白を残す。素材自体の黒をscreen blend等で透過させず、アートワークの黒階調と色を保持する。カード面も黒に近い低彩度へ変更。Cosmosの星は主点0.20／小点0.07、Neon線は当初0.10へ抑えた（下記のPulse専用改訂で変更）。シンプルダークでは背景装飾とthemeSurfaceの装飾縁を描かない。テーマ選択カードの選択枠は操作上必要な表示として残す。

## Pulse Neon — Light Sculpture

ユーザーのアート方向指定により、Pulseだけ強い明暗差へ改訂。他テーマの値は維持する。シアンの右上レールとエレクトリックブルーの左下レールを非対称に配置し、純黒の中央を空ける。折れ点に白い発光点、線には白い芯を設ける。文字とArtworkには発光を掛けない。

`PulseNeonLighting.swift`が形状と発光幅を所有。レールは画面幅の93%／6.5%に寄せ、halo 30pt × 0.045、bloom 12pt × 0.13、tube 3pt × 0.9、白芯0.8pt × 0.85、発光点半径2.5pt。背景の光量0.38、青#4263FF。面の方向性のある縁はシアン0.85／青0.48へ変更。継続animationや点滅は使わず、重ねたstrokeで静的に発光を表現する。透明度低減／increased contrast時は従来どおり装飾背景を外す。
