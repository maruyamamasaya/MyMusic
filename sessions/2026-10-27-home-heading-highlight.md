# 見出しアクセントとハイライトの配置

Context Guard MATCH、Git root確認。既存未コミット変更保持。

ユーザー訂正でHomeSectionSubtitleをHomeSectionTitleへ置換。チューニングはタイトル・副題とも対象外。発掘する音楽以降の各カテゴリ／作業用／MIX／プレイリスト／ステーションのsection見出しの先頭1書記素だけtheme accentにする。副題は元のsecondaryへ復元。「発掘する」を「発掘する音楽」に変更、個別タイルの発掘する音楽①／②は維持。

HomeHighlightTileはHomeItemTileと同じ内部配置へ変更。先頭の余分なSpacerを除去し、icon46pt・上余白14pt、下の文字群は高さ71pt（title最低40pt、description最低28pt、間隔3pt）へ統一。タイル168ptと既存背景・操作は維持。

外観のみにつきXCTest追加実行なし。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実画面の位置・大きい文字・各幅は未確認。実機未デプロイ。

指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）。git diff --check成功。
