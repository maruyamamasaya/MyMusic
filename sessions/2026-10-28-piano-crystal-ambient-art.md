# ピアノ背景とアンビエント候補

- Context Guard: MATCH。Git root確認、既存変更を保持。
- 明示指定のDownloads画像「虹色に輝く水晶のグランドピアノ.png」をpiano-crystal-v1.jpgへ768px JPEGで保存し、HomeDestination.pianoPlayに設定。原本は変更なし。
- HomeCategoryTestsの画像mapping期待値を追従。選曲・再生・永続化・アプリアイコン変更なし。
- アンビエントはbuilt-in image_genで候補を生成。採用前のため現在の曲Artwork参照を維持。
- 今回test未実行、test端末作成0・削除0。実機未反映。

## アンビエント生成候補

- built-in image_genを使用。虹色のガラスの波と静かな湖・オーロラ。候補のみ生成し未適用。
- 保存先: generated_images/ambient-options/01-crystal-lake.png。
- Prompt: Create one square album-style background artwork for an ambient music listening tile in a premium personal music player. A tranquil otherworldly glass landscape: smooth translucent opalescent crystal dunes and a still mirror lake, distant floating veil of aurora and soft mist, luminous cyan, lavender, pale rose and subtle warm champagne highlights. Spacious slow peaceful atmosphere, beautiful refractive light, sophisticated fine-art cinematic rendering, restrained detail, soft flowing forms rather than sharp chaotic shards. Main elegant iridescent glass arch or wave in upper center reflecting into the lake. Full bleed square composition, recognizable at small tile size, slightly subdued lower third for title overlay. No text, letters, logos, UI, instruments, music notes, people, borders. This is a standalone ambient music artwork, not an app mockup.
- 指定Simulator向けDebug build成功（BUILD SUCCEEDED）、piano-crystal-v1.jpgの同梱確認、git diff --check成功。


## アンビエント採用と実機デプロイ

- ユーザーの追加依頼で候補を採用。ambient-crystal-lake-v1.jpgへ768px JPEGとして保存しHomeDestination.ambientPlayの背景へ設定。
- HomeCategoryTestsの画像mapping期待値を更新。既存Git ignore規約を維持、原本保持。
- git status確認→check-iphone.sh成功→deploy-iphone.sh実行。
- Vespera / iPhone 17e / UDID 00008150-000C54280E33401C、paired・Developer Mode enabled・connected。
- Project: MyMusic.xcodeproj、Scheme／Product: MyMusic、Configuration: Debug、Bundle Identifier: maruyama.MyMusic。
- Build・Install・Launchすべて成功。CpResourceで新画像の同梱確認。
- 選曲・署名・識別子・Deployment Target変更なし。今回test未実行、test端末作成0・削除0。
- git diff --check成功。実機の外観・選曲体感はユーザー確認待ち。
- ログ: /tmp/mymusic-ambient-art-vespera-deploy.log。
