# 手動キュー編集とタイル画像

- Context Guard: MATCH。Git rootを確認、既存変更を保持。
- ManualQueueViewの待機曲を独立Sectionにし、左スワイプ削除とEditButtonによるドラッグ並べ替えを追加。
- ManualQueueStoreが待機リストoffsetをPlayerStoreのplaybackOrder位置へ変換し、既存removeQueueItems／moveQueueItemsを使用。再生中・再生済み曲は編集対象外。
- 編集後は期待queueと追加済みIDを同期。取り消した曲は候補から再追加でき、編集後に曲を追加してもqueueを誤ってリセットしない。
- タイル画像をbuilt-in image_genで生成。青紫ガラスのレコードを順に並べ、琥珀の光を添えた文字なし背景。
- 保存先: MyMusic/Resources/HomeTileImages/manual-queue-v1.jpg（768px JPEG）。既存規約どおり画像はGit ignore対象。元画像はCodex generated_imagesに保持。
- HomeDestination.manualQueueの画像mappingを追加。画像未配置時は既存gradientへfallback。
- 永続化形式・AVFoundation・署名設定の変更なし。実機への今回変更のデプロイは未実施。

## 生成プロンプト

Create one premium square background artwork for a personal music player's home tile 'Choose what plays next'. No text, letters, logos, numbers, UI, or borders. Rich dark navy and indigo background, cinematic sapphire and violet glass with small warm amber highlights. Main subject: a curated selection of five miniature translucent glass vinyl records in elegant sleeves arranged in a gently curving queue, one luminous record lifted slightly ahead of the others, suggesting choosing songs by mood and building a personal listening queue. Tactile polished metal grooves, gorgeous optical reflections, sophisticated photographic still life, close-up, full bleed. Keep composition recognizable at tiny 160px tile size, primary objects in center and upper right, subdued lower third and upper left so native title and icon can overlay legibly. Match a luxury local music app with blue-purple glass and golden light. Image is atmospheric artwork only, no app mockup.

## 検証

- 指定既存iPhone 17e Simulatorで関連35テスト成功（PlaybackHistoryBehaviorTests 26件＋HomeCategoryTests 9件）。並列test無効。
- 新規2テストで複数曲削除・再追加・一時停止維持・再生位置保持・再生済みと再生中の保護・上下移動・複数移動・編集後の追加・次曲への遷移を確認。
- 画像追加後の最終buildとXCTestDevices記録は下記へ追記。
- 実画面のドラッグ／スワイプと実機の確認は未実施。

- 画像追加後の指定Simulator向けDebug build成功。CpResourceでmanual-queue-v1.jpgの同梱を確認。
- git diff --check成功。専用lint設定なし。
- テスト端末の作成0・削除0。XCTestDevicesのUUID folderは開始前／終了後とも0件、残存合計12 KiB。削除なし。
- ログ: /tmp/mymusic-queue-edit-test.log、/tmp/mymusic-queue-edit-build.log。
