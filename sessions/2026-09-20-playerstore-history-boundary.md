# PlayerStore Watch安全確認と履歴記録の最小境界

## Phase 1.5: Watch分離の監査

- `PlayerStore`は`WatchPlaybackCoordinator`を強参照する。Coordinatorの`playbackCommand`と`shuffleCommand`がPlayerStoreを参照する箇所は双方`[weak self]`。Coordinatorが保持する`WatchConnectivityService`のhandler、`TrackPreferenceStore.stateChangeHandler`もCoordinatorを弱参照する。PlayerStoreとCoordinatorの強参照循環はない。
- 両クラスと`WatchConnectivityServicing`は`@MainActor`。`WatchConnectivityService`のWCSession delegateは受信時に`Task { @MainActor ... }`へ切り替えてからcommand handlerとstate providerを呼ぶ。WatchからSwiftUI Viewを直接変更する経路はない。
- `publishWatchState()`はoptionalのCoordinatorへ送るだけ。Watch未接続時の`playQueue`、`pause`、`next`、`previous`、`setShuffleEnabled`、`cycleRepeatMode`は引き続きPlayerStoreからAudioPlayerService/Queueロジックへ進み、Watch接続を前提としない。

## Phase 2 調査: 履歴の分類とタイミング

- **A 記録:** `recordPlaybackStartIfNeeded`から`recordPlaybackStarted`を呼び、初回/最終再生日時と入口別回数を更新。`recordListenedTime`は0～1.5秒の正の差分を集計し、30秒または曲長50%の閾値で`recordPlaybackCompleted`を一度呼ぶ。15秒間隔または強制時に`addPlaybackDuration`。`finalizeCurrentPlaybackSession`は一度だけ`recordPlaybackFinished`を呼ぶ。永続化は`PlaybackHistoryStore`が担う。
- **B 再生判断に使う履歴:** `startRemoteShuffle`の選曲、`rebuildPlaybackOrder`の除外判定・重み付けは`PlaybackHistoryStore`を読む。これらはPlayerStoreに残す。Mood Station等もHistoryを選曲に利用するが今回対象外。
- **C 再生文脈:** `currentPlaybackStartContext`、`startContext(for:)`、Queue/Shuffle/Repeat/Highlight等の入口・manual/automatic区分はPlayerStoreに残す。
- `AudioPlaybackEvent.playingChanged(true)`で開始記録、時刻eventで聴取時間と完了回数、`.ended`では履歴確定→再生状態/位置更新→次曲処理。`next`、`stop`、曲変更では移行前に履歴確定。background/lifecycleは時間flushだけ。今回、これらの順序やTask化は変更しない。

## 今回のSmall Step案

候補は`PlaybackHistoryCoordinator`へAの4つのStore記録呼び出しだけを同期委譲すること。PlayerStoreが再生時間、閾値、Context、終了種別、Queue/Shuffle/Repeatを決める境界は維持する。この最小実装を試したが、変更後buildが失敗したため、未検証のCoordinatorとPlayerStoreの履歴変更は戻した。履歴の本番コードは変更していない。

今回残した変更ファイル: `MyMusicTests/PlaybackHistoryBehaviorTests.swift`、本記録。並行して別作業のVisualizer関連ファイルと`PlayerStore.visualWorldSeed`が変更されたため、そこは変更・修復していない。

## 検証と停止理由

- 変更前のCharacterization Test: 既存iPhone 17e Simulator 1台で`PlaybackHistoryBehaviorTests` 10件成功。追加した3件はTrack EndのRepeat Off/All/One、Shuffle時の現在曲維持とNextの再生順を確認。Watchは接続していない。
- 試作後のbuildは失敗。`NowPlayingVisualWorldView.swift:142`で`VisualWorldScene`への`profile`引数が余分というコンパイルエラー。並行するVisualizer変更に由来し、履歴の差分ではない。ユーザー指定のStop条件により、履歴の試作を戻し、その後のTestと追加リファクタリングは実施していない。
- `git diff --check`成功。既存の専用lint設定なし。
- XCTestDevicesは開始前・終了時とも12KB、新規UUID folder 0、削除0。

## 未確認

Visualizer側を含む現行作業ツリーのbuild、実音源での曲終了とPause/Next/Previous、background復帰、Watch実機連携は未確認。Visualizer側のコンパイル状態が整った後、同じ対象をbuildとtestしてから履歴境界の妥当性を再判定する。
