# Hi-Res準備から通常再生へのcleanup待機

## 範囲

Context Guard MATCH、Git rootはMyMusic／main。既存の未コミット変更を保持。CURRENT.md、ARCHITECTURE.md、ADR-0007と開始／再開／stop経路を確認した。前のrate切替修正に続き、共有Audio Sessionの遅いdeactivateが通常再生を止める競合を対象とする。

## 変更

- HiResDirectOutputProbeStore.stopForPlaybackHandoffは同期停止後のpending taskを返す。明示stop後のidleでも未完了cleanupを返す。prepared状態のactive sessionも停止する。
- PlayerStore.beforePlaybackがpending taskを返すようにし、開始／再開taskは解放完了後に要求IDとキャンセルを再確認してから通常backendへ進む。MyMusicAppの共有Hi-Res callbackを接続。
- 設定Files診断は画面内Storeを維持する。表示中は弱参照の停止callbackをPlayerStoreへ登録。画面終了時にcallbackを外し、cleanup taskを保持させて通常再生開始前に待つ。複数の終了cleanupは順序付きで保持する。
- queue／履歴／Now Playing／EQ／normalizationの機能やAudioPlayerService内部は変更しない。
- 新規7テストで共有準備→通常開始／再開、Hi-Res明示停止後の開始、待機中の通常開始／再開キャンセル、表示中のFiles診断、画面終了後のFiles診断cleanupを検証する。spyは解放完了前のbackend activationを検出する。

## 検証

- 最終generic iPhone／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。
- 既存iPhone 17 Pro（F26F773A-A316-4610-9228-84217FEEB82A）1台、parallel testing無効／worker 1で対象XCTest 32件成功（追加7件＋既存25件）。PlaybackHistoryBehaviorTests、HiResRatePreparationTests、HiResPlaybackHistoryTestsを実行。
- git diff --check成功、専用lint設定なし。Xcode設定や外部依存の変更なし。
- XCTestDevices開始前／終了後のUUID folderはともに0件。新規作成／削除test端末0／0、残容量12KB。runtime／Simulatorの新規作成・downloadなし。
- 実機デプロイ未実施。

## 未検証・残課題

Tea Proでの全rate切替、初回接続、停止直後の再要求は実機確認が必要。Audio Queue停止／解放失敗時の打切りは今回の範囲外で、従来どおりログに残す。通常再生へ戻る実機操作は未確認、デプロイ未実施。
