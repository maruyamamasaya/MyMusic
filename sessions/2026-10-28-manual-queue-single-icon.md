# 手動キューの追加操作を整理

- Context Guard: MATCH。Git rootと作業ツリーを確認、既存変更を保持。
- ManualQueueViewの候補行から「最後に追加」iconを除去。
- 「次に再生」iconをtitle2 semiboldへ拡大、44pt操作領域とVoiceOver labelを維持。
- 曲名タップの末尾追加、初回選択、追加済み表示、Store／再生処理は維持。説明文を追従。
- 軽微な表示変更のためtest未実行、test端末作成0・削除0。実機未反映。
- 指定Simulator向けDebug build成功（BUILD SUCCEEDED）、git diff --check成功。

## Vesperaへの反映

- ユーザーの明示依頼でgit status確認→check-iphone.sh成功→deploy-iphone.sh実行。
- 対象Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。paired・Developer Mode enabled。check時tunnel disconnectedだがdeployで接続成功。
- Project: MyMusic.xcodeproj、Scheme／Product: MyMusic、Configuration: Debug、Bundle Identifier: maruyama.MyMusic。
- Build・Install・Launchすべて成功。既存作業ツリーを保持、署名・識別子・Deployment Target変更なし。
- 今回test未実行、test端末作成0・削除0。実機操作・外観はユーザー確認待ち。
- ログ: /tmp/mymusic-single-icon-vespera-deploy.log。
