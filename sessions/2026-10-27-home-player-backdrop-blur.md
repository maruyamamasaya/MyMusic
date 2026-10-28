# ホーム帯・ミニプレイヤーの背面ぼかし

Context Guard MATCH、Git root確認。既存未コミット変更を保持。

HomeSectionBackdropにultraThinMaterialを黒40%の下へ追加。帯の横幅と余白、文字・タイル画像を維持。simpleDarkのホーム下地なしを維持。通常ミニはScenerySmokedPanelのblursBackdropを有効化し、スモークgradient係数を0.90から0.45（実不透明度約40〜43%）へ変更してぼかした背面を透かす。金属枠・反射・表示・操作を保持。車窓HUDは既定falseで従来の表示を維持。

HiResMiniPlayerViewにもmaterial＋黒40%を適用。BottomPlayerLayoutの背面へThemeBackgroundを追加し、通常miniの独立領域でもテーマ背景を表示。各画面内の背景は従来経路を維持するため、領域間の画像crop連続性は未保証。Reduce Transparency／increased contrastではmaterialを省き不透明とする。再生Store／Service／保存の変更なし。

外観のみにつきXCTest未実行。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実機未デプロイ。スクロール負荷、mini再生中の見え方、全テーマ・Dynamic Type大は未確認。Materialのぼかし量はOS管理。

最終版は指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。git diff --check成功。今回のぼかし版の実画面は未確認。
