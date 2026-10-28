# 黒い下地を60%へ

Context Guard MATCH、Git root確認。ユーザー依頼でHomeSectionBackdrop、PlaybackMetadataBackdrop、HiResMiniPlayerViewの黒下地を0.40から0.60へ変更。ホームの全幅帯と再生中の曲情報・評価欄へ適用。追加ぼかしなし、accessibility時の不透明は維持。背景全体の黒20%と通常miniの既存スモークは対象外。保存・再生・構造に変更なし。

XCTest未実行（不透明度のみ）。test端末作成0／削除0、XCTestDevices未操作・容量未計測。実画面未確認、実機未デプロイ。

指定iPhone 17e Simulator向けDebug build成功（iPhone／Watch）。git diff --check成功。

## miniの透明度を維持

追加指示でminiは60%化の対象外へ修正。HiRes miniは黒40%へ復元、通常miniは元のglassOpacity 0.90を変更せず維持。ホームと再生中曲情報／評価欄のみ黒60%。ぼかしの再追加なし。実機未反映。
