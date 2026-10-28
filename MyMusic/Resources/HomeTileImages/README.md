# ホームのローカル背景画像

ホーム画面の「マイミュージック」左端にあるハイライトタイル、「ライブラリ」「アクティビティ」とステーション入口カードの背景画像を、ビルド／実機デプロイ前にローカルで差し替えるためのフォルダです。

## 使い方

1. このフォルダ（`MyMusic/Resources/HomeTileImages/`）へ画像を置きます。
2. 下表のベース名を正確に使います。拡張子は `.jpg`、`.jpeg`、`.png`、`.heic` のいずれかです。
3. Xcode で通常どおりビルドまたは実機デプロイします。

画像は Git の追跡対象外です。Highlightは画像を置かない場合にライブラリのArtworkをランダム表示し、Artworkもない場合は専用グラデーションを表示します。その他の画像を置かないタイル、ファイル名が違うタイル、読み込めない画像は、これまでどおり既存の配色グラデーションで表示されます。

## ファイル名

| セクション | タイル | ファイル名（推奨） |
| --- | --- | --- |
| マイミュージック左端 | ハイライト再生 | `highlight-background.jpg` |
| ライブラリ | 曲 | `library-songs-v2.png` |
| ライブラリ | アルバム | `library-albums-v2.png` |
| ライブラリ | アーティスト | `library-artists-v2.png` |
| ライブラリ | ジャンル | `library-genres-v2.png` |
| ライブラリ | 作曲者 | `library-composers-v2.png` |
| ライブラリ | 年 | `library-years.png` |
| アクティビティ | ランキング | `activity-ranking.png` |
| アクティビティ | 再生分析 | `activity-analytics-v2.png` |
| アクティビティ | 音楽史 | `activity-music-history-v2.png` |
| ステーション | 気分を伝えて再生 | `station-background.jpg` |

同じベース名で複数の拡張子を置いた場合は、`.jpg` → `.jpeg` → `.png` → `.heic` の順で最初に見つかった画像を使います。

## 画像の目安

- ライブラリ／アクティビティは正方形または縦長、1200 × 1200 px 以上を推奨します。
- ハイライトは正方形、1200 × 1200 px以上を推奨します。
- ステーションは横長、1600 × 900 px 以上を推奨します。
- タイルの比率に合わせて中央基準で切り抜かれます。
- タイトルを読みやすくするため、アプリ側で暗いグラデーションを重ねます。
- 元の配色へ戻す場合は、該当画像をこのフォルダから外して再ビルドします。

2026-10-27追加：最近の音楽傾向は`activity-music-trends.png`、作業用BGM再生は`work-bgm-background.png`を使用。分析と音楽史の旧jpgは保持し、v2画像へ参照を変更。4枚は文字なし・濃紺背景・ガラスと金属を共通にした生成画像です。

2026-10-27追加：ハイライトは`highlight-premium.png`を優先し、ない場合はライブラリArtworkを使用。Rediscovery Mixは`mix-rediscovery.png`を優先し、ない場合は先頭曲Artworkへ戻ります。旧highlight-background画像は保持します。

ハイライトはhighlight-vivid-coral／ocean／violet／lime.pngの4枚から初回抽選し、ホームのpull-to-refreshごとに前回以外を抽選します。highlight-premium.pngは保持していますが現在の抽選対象ではありません。

2026-10-27追加：曲・アルバム・アーティスト・ジャンル・作曲者はv2画像へ更新。年タイルに合わせた濃紺・青紫のガラスと琥珀色の光を共通とし、音符／レコードとジャケット／マイク／複数色のレコード／ペンと譜面で区別する。旧jpgは保持する。

Rediscovery Mixの現行画像は`mix-rediscovery-v2.png`。青緑・金とメタリック感を保持し、球状結晶から流れる金属とガラスの波形へ変更。旧mix-rediscovery.pngは保持。

Rediscovery Mixは現在`mix-rediscovery-v3.png`を使用。青緑と金の金属曲線を画面全体へ広げ、余白のないムーディーな構図へ調整。v1・v2は保持。


2026-10-27: playlist-more-v1.jpg（もっと見る／作業用の続き入口）とlibrary-hires-v1.jpg（ハイレゾ音源）をbuilt-in image_genで生成して追加。768px JPEG。前者はHomePlaylistMoreTile、後者は既存HomeDestination画像mappingを使用。生成プロンプトはsessions/2026-10-27-more-hires-highlight-layout.md。

2026-10-28: 発掘する音楽の「次に再生する」はmanual-queue-v1.jpg（768px JPEG）を使用。built-in image_genで青紫のガラスのレコードが順に並ぶ画像を生成。文字なし・琥珀色の光。プロンプトはsessions/2026-10-28-manual-queue-edit.md。未配置時は既存gradientを使用。

2026-10-28更新: 「次に再生する」はmanual-queue-cards.jpg／manual-queue-cassettes.jpg／manual-queue-notes.jpgの3枚からランダム表示。初回抽選・ホーム更新時に直前以外へ切替。768px JPEG、built-in image_gen。プロンプトはsessions/2026-10-28-records-icon-tile-options.md。旧manual-queue-v1.jpgは保持し、その元画像はアプリアイコンに採用。

2026-10-28: 「ピアノを聴く」はユーザー指定画像をpiano-crystal-v1.jpg（768px JPEG）として使用。画像未配置時は既存の曲Artwork／fallbackを維持。元画像はDownloadsに保持。

2026-10-28: 「アンビエントを聴く」は生成した湖・ガラスの波・オーロラのambient-crystal-lake-v1.jpg（768px JPEG）を使用。原本とプロンプトはsessions/2026-10-28-piano-crystal-ambient-art.mdを参照。未配置時は曲Artworkへfallback。

2026-10-28: ステーションは既存station-background.jpgとStationImages内のstation-golden-island.jpg／station-golden-spiral.jpgから初回抽選。ホーム更新で直前以外へ切替。生成画像は元画像の濃紺・金色の波・モザイク都市を参照。
