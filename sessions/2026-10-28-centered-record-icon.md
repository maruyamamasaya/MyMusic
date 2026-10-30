# アプリアイコンのレコードを中央へ

- Context Guard: MATCH。Git rootは指定MyMusic repositoryと一致。既存の未追跡generated_images/は保持。
- 元のglass-records-v1.jpegを保持し、右手前のレコードの軸が中央に来るようx=524/y=46から500px正方形を切り抜き、sipsで1024pxへ拡大。生成による絵柄変更なし。
- glass-records-centered.jpegを追加し、iOS AppIconの標準／dark／tinted参照を更新。Watch iconは変更なし。
- CURRENT.md更新。構造・音声・データ契約に変更なし、ARCHITECTURE/ADR更新不要。
- 出力画像を目視確認、git diff --check成功。
- 指定Simulator UDIDでbuildを試みたが、sandboxによるSwift/SwiftPMのユーザーcache書込拒否で終了（exit 74）。build未確認。ログ: /tmp/mymusic-centered-record-icon-build.log。
- test未実行。test端末作成0・削除0。XCTestDevices容量は未計測。
- 実機未デプロイ、ホーム画面での外観確認は未実施。
