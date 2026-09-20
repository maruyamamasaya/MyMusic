# PlayerStore履歴境界: 再生回数記録1件

## Baseline復旧

開始時の差分は、PlayerStoreのVisual seedとTrack Visual Profile関連のModel/View/Metal/文書・テスト、前回のHistory Characterization Test、前回の調査記録だった。WatchPlaybackCoordinator自体の未コミット差分やPlaybackHistoryCoordinatorの本番コードはなかった。

前回の`VisualWorldScene`への`profile`引数エラーを再確認すると、現在の`VisualWorldScene`には`var profile = TrackVisualProfile()`があり、`NowPlayingVisualWorldView`の`profile: profile`呼び出しと整合していた。Visualizerへの修正は0件。現作業ツリーのiOS/埋め込みWatch Simulator Buildは成功した。

全テストの初回実行はSimulatorがApp起動を`Busy (Application failed preflight checks)`で拒否し、テストは未実行。既存iPhone 17e Simulatorのboot完了を確認して同じコマンドを1回再試行し、XCTest 215件とSwift Testing 7件が成功。`PlaybackHistoryBehaviorTests` 10件と`WatchPlaybackCoordinatorTests` 1件も含む。

## 履歴の1処理だけを分離

`recordListenedTime(at:)`は引き続きPlayerStoreで差分・閾値・重複防止を判定する。閾値に達した時の`PlaybackHistoryStore.recordPlaybackCompleted(trackID:)`だけ、同期的な`PlaybackHistoryCoordinator.recordPlaybackCompleted(trackID:)`経由とした。Coordinatorは同じMainActor上で同じHistory Storeを呼ぶだけで、Queue、Shuffle、Repeat、Context、Audio Engine、Taskやactor境界に触れない。

Before: 時刻event → PlayerStoreで聴取差分・閾値判定 → History Storeが再生回数を記録 → PlayerStoreが`hasCountedCurrentPlay`を更新。

After: 時刻event → 同じ判定 → Coordinatorが同じHistory Storeを同期呼び出し → 同じflag更新。曲終了の履歴確定→次曲決定の順序は不変。

今回の本番コード変更: `MyMusic/Stores/PlaybackHistoryCoordinator.swift`、`MyMusic/Stores/PlayerStore.swift`、`CURRENT.md`、`ARCHITECTURE.md`。テストコードの追加・変更は今回なし。前回追加済みのCharacterization Testを再利用した。Visualizer関連差分は維持した。

## After検証

- iOS/埋め込みWatch Simulator Build成功。
- 同じ既存iPhone 17e Simulatorで全XCTest 215件とSwift Testing 7件成功。History 10件とWatch Coordinator 1件はBefore/Afterで成功。
- `git diff --check`成功。専用lint設定なし。
- 実音源、background復帰、Watch実機通信、Visual Worldの実機描画は未確認。
- XCTestDevicesのUUID folderは開始前・終了時とも0。test端末の作成0、削除0、残容量12KB。

次の候補は再生開始記録または聴取時間記録の依存確認。今回は進めない。
