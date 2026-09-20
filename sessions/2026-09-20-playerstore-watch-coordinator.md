# PlayerStore Watch 責務分離: 最初の Small Step

## Phase 0 調査

`PlayerStore` は953行。主な責務と変更者は以下の通り。

| 領域 | 主な状態・処理 | 依存・リスク |
| --- | --- | --- |
| Playback / Session | `currentTrack`, `isPlaying`, `currentTime`, `duration`, `playQueue`, `pause`, `resume`, `seek`, `stop`, `startPlayback`, `handle` | `AudioPlayerService` のevent、Task、AVAudioSession。処理順序に高リスク |
| Queue / Shuffle / Repeat | `queue`, `currentIndex`, `playbackOrder`, `isShuffleEnabled`, `repeatMode`, `next`, `previous`, `rebuildPlaybackOrder`, `advanceAfterTrackEnded` | Viewもqueueや再生可否をobserve。曲順・終了遷移に高リスク |
| History / Context | 再生開始・聴取時間・確定・flush、`currentPlaybackStartContext` | `PlaybackHistoryStore`、backgroundでのflush。重複記録にリスク |
| Now Playing / Remote | `nowPlayingService`、`remoteCommandService` | `MediaPlayer` の状態と遠隔操作。再生stateとの同期に高リスク |
| Watch | `connectWatch`、Watch state生成・publish、`startRemoteShuffle` | `WatchConnectivityService`、`TrackPreferenceStore`、`LibraryStore`。commandのactor・同期順序に注意 |
| Visual / Audio Analysis | `spectrumLevels`, `spatialSnapshot`, `visualAudioFrame`, `audioInformation` | `AudioPlayerService` callbackとViewのobserve。再生tapには触れない |
| Track adjustments / Normalization | 曲別開始・終了・位置、gain、特徴量取得 | `TrackPlaybackAdjustmentStore`と非同期load。終了判定と再生開始に高リスク |

Viewは`PlayerStore`の再生状態・queue・visual frameを直接observeする。Watchは`WatchConnectivityService`経由でcommandを受け、`TrackPreferenceStore`がFavorite/Preferenceの正本、`LibraryStore`がWatch Shuffle時の最新曲一覧を提供する。`RootView`はbackground移行で位置・履歴をflushする。

分離順序は Watch接続 → History記録 → Visual frame受け渡し → Queue/Shuffle/Repeat → Session を推奨。後半ほど再生遷移・Observation・AudioPlayer callbackへの依存が強い。

## Phase 1: Watch接続だけを分離

`WatchPlaybackCoordinator`を追加し、通信serviceのactivate、command振り分け、Preference操作、Watch state生成・publishを移した。Coordinatorは再生engineを所有せず、`PlayerStore`へのcommand closureは弱参照。Shuffle選曲・queue変更・再生結果判定は従来の`PlayerStore.startRemoteShuffle`に残した。`WatchConnectivityService`のWCSession/Artwork実装、message contract、再生順序、UI APIは変更していない。

変更ファイル: `MyMusic/Stores/PlayerStore.swift`, `MyMusic/Stores/WatchPlaybackCoordinator.swift`, `MyMusicTests/WatchPlaybackCoordinatorTests.swift`, `CURRENT.md`, `ARCHITECTURE.md`, 本記録。作業開始前からのVisualizer関連未コミット差分は維持した。

## 検証

- `xcodebuild -project MyMusic.xcodeproj -scheme MyMusic -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`: **BUILD SUCCEEDED**。
- 既存iPhone 17e Simulator 1台、並列無効で`WatchPlaybackCoordinatorTests` 1件、`WatchPlaybackMessageTests` 6件、`PlaybackHistoryBehaviorTests` 7件: **14件成功、失敗0**。Watch commandの振り分け、state publish、message互換、既存のNext/Shuffle/Repeat履歴経路を確認。CoordinatorテストへWatch Shuffle委譲の確認を追加し、同テストだけ再実行して**1件成功**した。
- 最初の`-sdk iphonesimulator`指定buildは、Watch targetにもiOS SDKが適用されWatch AppIconが不適合となり失敗。targetごとのSDKが選ばれるdestination指定で解消。ソースのエラーではない。
- `git diff --check`成功。専用lint設定なし。
- XCTestDevicesに新規UUID folderは作成されず、削除0、残容量12KB。

## 未確認・次の作業

実音源でのPlay/Pause/Resume/Next/Previous、Shuffle/Repeat、曲変更、background復帰、およびWatch実機接続・command・Favorite/Preference・Artwork・iPhoneからのstate同期は手動確認が必要。Simulatorの単体テストでは実機WCSessionの到達性を検証できない。次の候補はHistory記録だが、この段階では変更しない。
