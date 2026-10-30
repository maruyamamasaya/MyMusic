# 作業用リスト作成の背景画像

- Context Guard: MATCH。Git root／作業ツリー確認、既存変更を保持。
- 指定Downloads画像をHomeTileImages/work-playlist-create-v1.jpgへ768px JPEGとしてコピー。原本保持、既存Git ignore規約を維持。
- HomePlaylistEmptyTileへoptional画像指定を追加し、作業用リスト作成だけに適用。既存loader・暗いgradientで文字の視認性を確保。
- 通常のプレイリスト作成tile・操作・保存は維持。
- CURRENT／ARCHITECTURE／画像README更新。
- 表示のみのためtest未実行、test端末作成0・削除0。実機未反映。
- 指定Simulator向けDebug build成功（BUILD SUCCEEDED）、git diff --check成功。

## Vesperaデプロイ

- ユーザー明示依頼でgit status確認→check-iphone.sh成功→deploy-iphone.sh実行。
- Vespera / iPhone 17e / UDID 00008150-000C54280E33401C、paired・Developer Mode enabled・connected。
- Project MyMusic.xcodeproj、Scheme／Product MyMusic、Debug、Bundle ID maruyama.MyMusic。
- Build・Install・Launchすべて成功。既存変更を保持し署名等の設定変更なし。
- test未実行、test端末作成0・削除0。実機外観はユーザー確認待ち。
- ログ: /tmp/mymusic-work-art-vespera-deploy.log。
