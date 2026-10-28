# レコードのアプリアイコンと選曲タイル3画像

- Context Guard: MATCH。Git root確認、既存変更を保持。
- 添付画像を1024px不透明JPEGとしてAppIcon/glass-records-v1.jpegへ保存し標準／dark／tintedに設定。旧iconは保持。
- built-in image_genで選曲カード／カセット／音符を生成。元画像はgenerated_images/manual-queue-options/の01-glass-selection.png、02-crystal-cassettes.png、03-glass-notes.pngへ保存。
- HomeTileImages/manual-queue-cards.jpg、manual-queue-cassettes.jpg、manual-queue-notes.jpgへ768px JPEGを配置（既存Git ignore規約を維持）。
- 追加指示で3枚すべて採用。HomeView初期化時抽選、pull-to-refreshで直前以外を抽選。HomeCarouselSection経由でHomeItemTileへ画像名を渡しtask(id:)で再読込。
- 旧manual-queue-v1.jpg保持。再生・JSON・署名・識別子変更なし。実機未反映。
- icon単独の指定Simulator向けbuild成功。test未実行、test端末作成0・削除0。

## 生成プロンプト（built-in image_gen）

### 1

Create a premium square background artwork for a music app tile used to choose the next song and build a queue. Photographic luxury still life, dark navy background, sapphire and violet optical glass, warm gold highlights, highly legible bold central subject at 160px size, full bleed, no text, no letters, no numbers, no logos, no UI, no borders. Lower third subdued for native title overlay. Concept 1: A luminous glass jukebox selection carousel, five small jewel-like album cards floating along a curved polished brass rail, one glowing card gently pulled forward. Elegant sculptural music selector, intimate moody lighting, tactile glass and metal. Do not depict vinyl records in sleeves.

### 2

Create a premium square background artwork for a music app tile used to choose the next song and build a queue. Photographic luxury still life, dark navy background, sapphire and violet optical glass, warm gold highlights, highly legible bold central subject at 160px size, full bleed, no text, no letters, no numbers, no logos, no UI, no borders. Lower third subdued for native title overlay. Concept 2: Three beautiful translucent crystal cassette tapes forming a flowing diagonal queue, one forward in warm amber light and the others cobalt and violet behind it. Sculptural futuristic cassette mechanisms, subtle golden light linking the tapes, cinematic close-up on a black reflective surface. No vinyl records.

### 3

Create a premium square background artwork for a music app tile used to choose the next song and build a queue. Photographic luxury still life, dark navy background, sapphire and violet optical glass, warm gold highlights, highly legible bold central subject at 160px size, full bleed, no text, no letters, no numbers, no logos, no UI, no borders. Lower third subdued for native title overlay. Concept 3: A luminous sapphire glass musical note sculpture at the front of a graceful sequence of smaller violet and amber glass note sculptures, arranged along a curved golden ribbon like songs waiting their turn. Rich premium realistic glass refraction, close-up on dark reflective stone, sparse bold composition. No vinyl records or album sleeves.


## 最終確認

- 指定iPhone 17e Simulator destinationのDebug build成功（BUILD SUCCEEDED）。生成3枚のCpResourceを確認。
- git diff --check成功。表示asset変更のためtest未実行。実画面・実機未確認。
- ログ: /tmp/mymusic-random-queue-art-build.log。
