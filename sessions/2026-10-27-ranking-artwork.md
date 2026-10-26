# ランキングタイル画像

- Context Guard MATCH。MyMusic Git root一致。
- built-in image_genで新規生成し、MyMusic/Resources/HomeTileImages/activity-ranking.pngへコピー。元画像も保持。既存画像の上書きなし。
- HomeDestination.artistRanking.localBackgroundImageNameへactivity-rankingを設定。既存の中央crop・可読性maskを使用。READMEへ名前を追記。
- 生成指示：文字なし、正方形、音楽ランキング用の抽象的なガラスとクロームの上昇する柱・金属の波形、濃紺背景、cyan／violetのedge lightと頂点のgold、下側はタイトル用の暗い余白。人物・ロゴ・数字・文字・literal trophyなし。
- 生成画像を目視確認。git diff --check実施。build／test／deploy未実施、実際のタイルcropは未確認。
- フォルダの既存運用に従い画像はGit対象外（ローカルbuildへ同梱）。ソース参照と文書は追跡対象。
- テスト端末作成・削除0台、XCTestDevices調査・変更なし。
