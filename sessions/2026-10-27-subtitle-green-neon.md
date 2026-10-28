# ホーム副題のアクセントとNeonの緑化

Context Guard MATCH、Git root確認、既存未コミット変更を保持。

HomeSectionSubtitleを追加し、ホームのチューニング・各category・作業用・MIX・プレイリストの副題先頭1書記素だけをテーマaccentで表示。AttributedStringで一つのTextを維持し、残りはsecondary、既存font・lineLimit・レイアウトを維持。タイル内の説明文は対象外。

Pulse Neonのaccentを#7FFFA6、lightを#19B879へ変更。生成背景画像はNeonだけhueRotation -65度で緑へ寄せる。他テーマとArtwork、意味を持つ評価色、保存IDは維持。新規画像生成なし。新テーマは暖色のAmber Loungeを提案するが未実装。

XCTest未実行（外観のみ）、test端末作成0／削除0、XCTestDevices未操作・容量未計測。実画面・実機の色と可読性は未確認。実機デプロイなし。

指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）。git diff --check成功。
