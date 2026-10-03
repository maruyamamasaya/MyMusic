# ハイレゾ再生画面への共通入口

## 作業

- MyMusicAppでライブラリ用HiResDirectOutputProbeStoreを保持し、Environmentで共有する。
- RootViewのタブ共通下部accessoryで通常／ハイレゾのミニプレイヤーを切り替える。ハイレゾ専用sheetもRootViewから表示する。
- HiResLibraryViewと各詳細の画面内ミニプレイヤーを除去し、画面離脱時のstopを除去した。画面を閉じても再生・一時停止・自然終了後の状態を保持する。
- Appで弱参照のbeforePlayback callbackを接続し、通常／ハイレゾ開始・再開前に他方のactive再生を停止する。設定のFiles診断開始時も共有ハイレゾを停止する。
- CURRENT.md、ARCHITECTURE.mdを更新。既存の音楽史／Watch同期に関する未コミット変更は維持した。

## 検証

- generic iOS Simulator Debug build成功（埋め込みWatch含む）。sandbox内では標準cacheへの書込が拒否されたため、許可された標準Xcode実行で検証した。
- 既存iPhone 17 Pro / iOS 26.5 Simulator 1台、parallel testing無効でHiResPlaybackHistoryTests 8件とPlaybackHistoryBehaviorTests 13件、計21件成功。
- 新規テストでハイレゾ開始／resume前のhandoff、sheet表示状態変更後のpaused保持、通常開始／resumeのhandoffを確認した。
- git diff --check成功。専用lint設定はない。既存のMusicHistoryViewのSwift 6 async警告とApp Intents metadata警告は残る。

## 未確認・制約

- 各タブでのミニプレイヤー表示、タップ、sheet開閉、小画面・Dynamic Typeの見た目は未確認。
- USB DAC実機での画面移動後の継続再生、rate切替、長時間再生は未確認。
- 独立Audio Queue backendを維持する。Now PlayingのOS連携、remote command、Watch操作、background制御、EQ等の統合は今回追加していない。

## Xcodeストレージ

- XCTestDevices: 開始前のUUID folder 0個／合計0 KiB、終了後も0個／合計0 KiB。
- 作成したtest端末0個、削除0個。既存Simulatorを使用し、runtime追加・DerivedData削除は行っていない。
