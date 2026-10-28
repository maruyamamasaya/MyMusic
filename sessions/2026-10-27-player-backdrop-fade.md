# 再生中の曲情報下地の境界をなじませる

Context Guard: MATCH。Git rootがMyMusicであることを確認。既存の未コミット変更を保持。

ユーザー承認の案に従い、PlaybackMetadataBackdropの中央は黒60%のまま、上下に各16ptの透明へ抜けるgradientを追加。背面のみ外側へ拡張し、曲情報・評価欄・シークバーの配置は変更しない。通常／作業用／HiResの既存共通modifierに適用。blur・material・依存追加なし。透明度低減／高コントラスト時は従来の不透明黒を維持。

表示だけの変更であり、構造・データフロー・永続化・再生処理の変更はないためARCHITECTURE更新・ADR追加は不要。

検証: 指定iPhone 17e Simulator UDID向けDebug build成功（iPhone／埋め込みWatch）。最初のbuildはsandboxのキャッシュ書き込み制限で失敗し、権限付き再実行で成功。git diff --check成功。実画面での外観・Dynamic Type・各テーマの見え方は未確認、実機未デプロイ。

表示のみの小変更のためXCTest未実行。test端末作成0／削除0。XCTestDevices未操作、残容量未計測。

## 実機デプロイ

ユーザーの明示依頼によりgit status確認後、check-iphone.sh成功、deploy-iphone.sh成功。初回端末確認はsandbox内でtimeout、権限付き再実行で接続確認。対象VesperaはiPhone 17e、UDID `00008150-000C54280E33401C`。MyMusic.xcodeproj／scheme MyMusic／product MyMusic.app、Debug、Bundle Identifier `maruyama.MyMusic`。Build／Install／Launchすべて成功。既存の未コミット変更を含む現在の作業ツリーをそのまま導入し、アプリソース・署名・識別子・project設定は今回のデプロイで変更していない。実機の外観・操作はユーザー確認待ち。XCTest未実行、test端末作成0／削除0、XCTestDevices未操作・残容量未計測。
