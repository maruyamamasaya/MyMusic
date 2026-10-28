# ハイライト・Rediscovery Mix画像

- Context Guard MATCH、MyMusic Git root一致。既存変更を保持。
- built-in image_genで文字なし正方形の画像2枚を生成し、Resources/HomeTileImages/highlight-premium.pngとmix-rediscovery.pngへコピー。旧画像と生成元を保持。既存画像運用に従いGit対象外。
- ハイライト生成指示：最もよく見る主役のタイル、上質な磨いたplatinumとsmoked crystalの一つのloopがchampagne goldの光核を包む、cyan／violetのedge dispersion、精緻な微細質感、濃紺背景、下側は白いラベル用の暗い余白。文字・ロゴ・数字・UI・人物なし。
- Rediscovery生成指示：忘れていた音楽の再発見、sapphire glassとtitaniumの開いたspiral、内側のamber光とcyan／emeraldの縁、神秘的で落ち着いた同シリーズの質感。文字・ロゴ・数字なし。
- HomeHighlightTileとHomeMixTileに既存HomeTileBackgroundImageによる画像loadを追加。GeometryReaderでtileの枠内へscaledToFillし、既存の暗幕と文字・操作は維持。画像がない場合のライブラリArtwork fallbackを保持。選曲・再生・保存契約変更なし。
- 生成画像は目視確認、git diff --check実施。build・test・deployと実際のtile crop確認は未実施。テスト端末作成・削除0台、XCTestDevices変更なし。
