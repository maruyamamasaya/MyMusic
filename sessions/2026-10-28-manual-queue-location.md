# 手動キュー入口の移動

- Context Guard: MATCH。MyMusic Git root確認、既存変更を保持。
- HomeCategoryのmanualQueueをexploreからmyMusic先頭へ移動。
- myMusicの内容有無filterではmanualQueueを常時表示。先頭入口がsnapshotのinstantPlaybackIsAvailable未定義で消えないようにした。
- HomeCategoryTestsの既存期待値を配置・filterに追従。
- 再生・保存・構造の変更なし。実機未反映。
- 低影響の配置変更のためtestは実行せず、指定Simulator向けbuildで確認。test端末作成0・削除0。
- 指定destinationのDebug build成功（BUILD SUCCEEDED）、git diff --check成功。
