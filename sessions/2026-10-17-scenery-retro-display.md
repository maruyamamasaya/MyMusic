# 車窓HUDのスモーク液晶・日本語ドット表示 — 2026-10-17

## 変更

- ユーザーと確認した参考イメージに沿い、車窓だけを白青いドット文字・暗いスモーク調パネルへ変更。ブランドロゴや固有の製品外形は使わない。
- 最大幅は展開410／縮小270pt、Artwork36pt、既存padding・右下配置は維持。文字列の表示幅を明示し、最終panel boundsでもclipする。
- DotGothic16をNOW PLAYING／PAUSED、曲名、Artistへ適用。文字の大きさと行高はScaledMetricでDynamic Typeへ追随する。色は白に近い淡い青、透明度低減時はパネルを不透明にする。
- 再生／一時停止と次曲を金属gradient・rim・小さなshadowで描く。他の操作は背景なしのハート／グッドicon。共通評価部品にはoptionalのinactiveColorだけを追加し、指定しない通常画面は従来どおり。
- 追加要望で縮小矢印を削除。曲名／Artistの領域tapで縮小・展開の両方向をtoggle、Artworkは常に戻る。縮小時もNOW PLAYING／PAUSEDと1pt進捗を維持する。
- 保存、選曲、評価値、動画・音楽の実再生、回転は変更しない。

## 文字スクロール

SceneryDisplayTextを車窓専用に追加。単一行へ空白を正規化し、同じDotGothic16のText実幅と表示窓幅を測る。overflowが1pt以上ある場合、先頭で1.8秒停止→毎秒16ptのlinear左移動→末尾で1秒停止→先頭へ即時復帰、を繰り返す。曲名とArtistは独立した窓を持つ。短い文字は静止。

文字変更・幅変更・scene状態変更でTaskを更新する。Reduce Motion／scene非active時は先頭の静止表示。HUDが消えた時はSwiftUIのtask cancellationで停止する。既存の汎用MarqueeTextは変更しない。VoiceOverはclipされた部分ではなく全文を読む。

## フォント資産

- FontworksのDotGothic16。日本語の16×16ドットに基づく書体。漢字・かな・英数字対応。
- 公式説明: https://github.com/fontworks-fonts/DotGothic16/blob/master/README-JP.md
- 取得元: https://raw.githubusercontent.com/google/fonts/main/ofl/dotgothic16/DotGothic16-Regular.ttf
- license取得元: https://raw.githubusercontent.com/google/fonts/main/ofl/dotgothic16/OFL.txt
- Copyright 2020 The DotGothic16 Project Authors。SIL Open Font License 1.1をResources/Fonts/DotGothic16-OFL.txtへ原文同梱。
- TTF約2MB。外部libraryを増やさず日本語を含む希望の書体を表示するための意図的なbundle資産。UIAppFontsへの登録以外のplist・署名・識別子変更なし。
- SHA-256: 3ad9af88726d42b40f7f365f0dcac785af73cf20ea6f1d5b44e57cc21150b8f1

## 検証

- 最終Swift変更のiPhone／埋め込みWatch generic Simulator Debug build: BUILD SUCCEEDED。
- build出力でTTFとlicenseのMyMusic.appへのcopyを確認。
- macOS CoreTextでTTFを登録しPostScript名DotGothic16-Regularを確認。サンプル漢字・ひらがな・カタカナ・英数字のglyph非0を確認。
- 実SceneryBGMOverlay／SceneryDisplayText／appearanceをmacOS ImageRendererで描画して確認。player／Artwork／評価部品はサンプルstub、scene inactiveで静止表示のため、実機の動画・評価動作やスクロールの動作確認ではない。
- プレビューで幅のはみ出しを確認して固定幅とpanel clipを修正。再生／次曲のmetal質感、漢字表示、縮小進捗を画像確認。
- 今回の実機デプロイは未実施。スクロールの速度・停止・長い日本語・Dynamic Type・Reduce Motion・background復帰は実機確認が残る。pixel fontの小さい漢字の可読性も確認が必要。
- 初期の静止HUDに対する電力比較結果を、このアニメーション追加版へ流用しない。
- git diff --checkで確認。専用lintなし。XCTest／Simulator testは未実行、test端末作成0／削除0。Xcode data削除なし。
