# 追加ぼかしの撤去・黒40%下地へ修正

Context Guard MATCH、Git root確認。ユーザーの再指定に従い、弱いぼかしも含め今回追加したblurをすべて撤去。SubtleBackdropBlur.swiftを削除し、HomeSectionBackdrop／PlaybackMetadataBackdrop／通常・HiRes miniの参照を除去。

ホームは左右いっぱい・余白なし・角丸なしの黒40%帯を維持。通常／作業用／HiRes再生中の曲名・Artist・Album・再生回数・既存評価操作欄にも、角丸なし・画面左右いっぱいの黒40%下地だけを配置（親の横24ptを背面だけ相殺）。文字・Artworkはぼかさない。Reduce Transparency／increased contrastでは不透明を維持。

通常miniは追加blur前のスモークgradient係数0.90へ復元。ぼかし用に追加したBottomPlayerLayoutのテーマ背景も撤去。HiRes miniは黒40%だけを維持。従来のヘッダー黒gradient、背景全体の黒20%は維持。OS標準のmenuやtab bar等は変更しない。Store・再生・保存変更なし。

XCTest未実行。test端末作成0／削除0、XCTestDevices未操作・容量未計測。今回版は実機未デプロイ、実画面未確認。

指定iPhone 17e Simulator（EB3A49ED-6553-4D7E-B933-387951643EAB）向けDebug build成功（iPhone／Watch）。対象4部品に追加blur／material参照がないことを確認。git diff --check成功。
