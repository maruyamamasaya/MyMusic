# 墨和紙の隷書体・黎明の太字明朝

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

ユーザー依頼でThemeTypographyの墨和紙は明朝案から隷書体へ変更、黎明は太字明朝へ変更。ホームsection見出し、テーマ選択title、通常／作業用／HiRes／Highlightの曲名に既存helperを通じて適用。本文・一覧・操作は維持。

墨和紙は武蔵システム公式配布https://opentype.jp/aoyagireisho.htmから「青柳隷書しも」OpenType Version2.01を取得。使用方法の原文で無料使用・商用可・無料再配布可と説明書同梱条件を確認。MyMusic/Resources/Fonts/AoyagiReishoへOTF（約4.6MB）・使用方法TXT・解説PDF／DOCと出典READMEを追加。UIAppFontsに1項目追加。CoreTextでPostScript名aoyagireisyo2を確認。フォントは無改変、外部ライブラリ追加なし。使用方法の連絡は不要との記述に従い外部への連絡はしない。

黎明は標準HiraMinProN-W6を優先し、ない場合W3.bold、最後はsystem serif.boldへfallback。墨和紙はaoyagireisyo2をFont.custom(relativeTo:)で使用し、サイズは既存20／22ptを維持。

指定iPhone 17e SimulatorでAppThemeTests 5件成功。新規testReishoFontIsRegisteredFromAppBundleでUIFontの実登録を確認し、7テーマ通常／accessibility3の描画・保存復元・Visual World独立性も成功。並列無効・worker1・destination1。iPhone／Watch compile成功、git diff --check成功。

XCTestDevicesは前後とも空、合計0 bytes。test端末作成0／削除0、削除操作なし。実機未デプロイ。実曲名での全画面可読性・glyph fallback・marqueeの大文字時の行高は実機未確認。

## 実機デプロイと追加のフル再生アイコン

ユーザーの明示依頼でcheck-iphone.sh成功後deploy-iphone.shを実行。初回はフォント説明README.mdと既存HomeTileImages/README.mdのresource出力名競合でbuild失敗。フォント側の説明をAoyagiReisho-Source.mdへrenameして内容を保持し、再実行でBuild・Install・Launch成功。

追加依頼でHighlightPlayerViewの「フルで再生」をplay.rectangle.fillのiconOnly／42ptへ変更。通常の再生マークと区別する枠付き表現とし、VoiceOverのラベル・ヒントを明示。onFullPlaybackと再生処理は維持。追加版もdeploy-iphone.shでBuild・Install・Launchすべて成功。

最終対象: Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C、MyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle ID maruyama.MyMusic。未コミット変更保持、署名等の設定変更なし。今回XCTest追加実行なし、test端末作成0／削除0。実機のfont・icon外観と操作はユーザー確認待ち。
