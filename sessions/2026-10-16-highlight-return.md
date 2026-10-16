# ハイライト画面への復帰

- 原因: HomeのHighlight destinationのonDisappearがresetRandomSelectionを呼び、候補とactive状態を破棄していた。ミニプレイヤーは通常sheetだけを開いていた。
- PlayerPresentationMode.highlightを追加。HighlightのplayQueue／別の部分のseekで指定し、RootViewのmini playerからHomeの既存destinationへ戻す。
- resetは通常再生からHomeのHighlightタイルを開く時へ移動。同じlibraryでの画面再作成はqueue／候補／再生位置／pause状態を維持する。
- フル再生・外部の通常再生・stopは既存のstandard指定へ戻る。同一曲を通常再生しても旧Highlight自動advanceが割り込まないようmodeも確認する。
- 保存形式、選曲policy、音声backendは変更しない。アプリ終了後の復元は対象外。
- 状態保持とフル／同一曲の通常再生への切替の対象XCTestを2件追加。
- test開始前のXCTestDevices UUID folderは0、合計0 KiB。既存iPhone 17e Simulator 1台を使用し並列test無効。
- 実機の画面遷移／scroll位置と別tabからの復帰は未検証。デプロイ未実施。
- 対象XCTest 2件成功（0 failures）。test後もXCTestDevices UUID folder 0、合計0 KiB。新規作成・削除0台。既存Simulator利用のみ。
- generic iPhone／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。git diff --check成功。
- 2026-10-16: Vespera（00008150-000C54280E33401C）へMyMusic.xcodeproj／MyMusic scheme／maruyama.MyMusicのDebug build・install・launch成功。初回CoreDevice timeout後、権限付き再試行で成功。ユーザーがホーム→ミニプレイヤー→ハイライトへの復帰を実機確認。
