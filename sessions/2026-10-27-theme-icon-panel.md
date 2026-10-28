# ホームテーマ切替アイコンパネル

- Context Guard: MATCH。Git rootはMyMusic。開始時の未コミット変更を保持。
- HomeThemeCycleButtonの数字を月／オーロラ／波形／星のSF Symbolsへ置換。モノトーン、半透明の小さな角丸パネル。左手前の現在アイコンと右奥の次アイコンを表示し、springで入れ替える。
- 44ptの操作高さ、VoiceOverの現在／次テーマ案内、Reduce Motion／Reduce Transparency対応。既存Store・保存順序・再生処理は維持。新規画像・依存追加なし。
- 指定iPhone 17e Simulator destinationでDebug build成功（iPhone／Watch）。初回sandbox内buildはキャッシュ権限・Simulator接続で失敗し、権限付き再実行で成功。
- 外観のみのためXCTest未実行。test端末の作成0／削除0。XCTestDevicesは未操作、残容量未計測。
- 実画面の配置・連続タップ時の体感・Dynamic Type大・実機は未確認。実機デプロイなし。

## 実機デプロイ

ユーザーの明示依頼でVespera（iPhone 17e、UDID 00008150-000C54280E33401C）へデプロイ。sandbox内の端末確認はtimeout、権限付きcheck-iphone.shは成功。続いてdeploy-iphone.shによりMyMusic.xcodeproj／scheme・product MyMusic／Debug／Bundle Identifier maruyama.MyMusicのBuild・Install・Launchがすべて成功。既存の未コミット変更を含む作業ツリーを使用。署名設定等の変更なし。見え方・操作感はユーザー実機確認待ち。XCTest未実行、test端末の作成・削除0。
