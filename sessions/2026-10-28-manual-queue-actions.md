# 候補行の次再生・末尾追加

- Context Guard: MATCH。MyMusic Git rootと既存変更を確認し保持。
- ManualQueueViewの「次に聴く曲を選択」の候補行に「次に再生」「最後に追加」のSF Symbols buttonを追加。各44ptの操作領域、VoiceOver label・helpあり。
- 候補行のみTrackRowViewの時間表示を省略。showsDurationは既定trueで他画面を維持。
- 初回は従来どおり最初の曲を選択して再生。再生開始後は右の2操作で追加位置を指定し、曲名タップは末尾追加。
- ManualQueueStore.selectからPlayerStore.appendToManualQueueへplayNextを伝達。次再生はplaybackOrder上で現在位置の直後、末尾指定は最後へ追加。複数回の次再生は直近指定を優先。
- 追加済みの重複防止・取消後の再追加・全曲終了後の再開・一時停止維持を継続。
- 保存schema・AVFoundation・署名変更なし。今回変更は実機未反映、実画面未確認。

## 検証

- 指定iPhone 17e Simulatorを再利用、並列test無効。
- 新規テストで次再生／末尾の混在・連続挿入・再生位置保持・挿入した曲の取消・実際の次曲遷移・一時停止中の挿入を確認。
- 最終結果は下記へ追記。

- 指定destinationでDebug build成功（BUILD SUCCEEDED）。関連36テスト成功（PlaybackHistoryBehaviorTests 27件＋HomeCategoryTests 9件）。
- git diff --check成功。専用lint設定なし。
- テスト端末作成0・削除0。XCTestDevicesのUUID folderは開始前／終了後とも0件、残存12 KiB。削除なし。
- ログ: /tmp/mymusic-queue-actions-test.log、/tmp/mymusic-queue-actions-build.log。
