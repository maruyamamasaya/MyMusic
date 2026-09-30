# 起動時ライブラリ読み込み

- Context Guard: MATCH。Git root確認済み。
- 初回復元はgenre filterの表示snapshot反映まで待つ。同時復元呼び出しも完了まで待つ。
- 復元とscanの読み込み状態を合成し、HomeとLibraryへ起動読み込み表示を追加。folder復元前の未選択表示を抑制。
- cache読取失敗を隠して全scanする処理を廃止し、エラーと手動クイック同期の案内を表示。cache欠落folderのscan、新旧decode契約、metadata revisionは維持。
- 全曲symlink解決は重複登録防止に関係するため維持。分類再構築も今回は変更しない。実機のcold launch時間／表示は未計測。
- 検証: generic iOS Simulator Debug BUILD SUCCEEDED。LibraryGenreFilterTestsとTrackFirstSeenAtTestsの対象XCTest 19件成功。git diff --check成功。専用lintなし。
- 初回sandbox buildはXcode cache権限不足で失敗。権限を拡張した再実行で成功。
- testは既存iPhone 17 Pro Simulator 1台、parallel無効／worker 1で実施。XCTestDevices開始前UUIDはEC34D0A2-B5CD-4DF2-84F3-121E9A114BFB（3,646,888 KiB）、root合計3,646,900 KiB。終了後UUID一覧とroot容量は同一。作成0台、削除0台、残量約3.48 GiB。既存データは保持。
- アーキテクチャ文書へ初回完了境界を追記。永続化schemaの変更なし。
- 既存未追跡sessions/2026-10-01-device-deployment.mdは変更していない。実機デプロイは実施していない。

## Vesperaへの導入とWatch調査

- 明示依頼によりgit status確認、check-iphone.sh成功後にdeploy-iphone.sh実行。
- MyMusic.xcodeproj / scheme MyMusic / product MyMusic / Debug / Bundle Identifier maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401CへBuild / Install / Launchすべて成功。未コミット変更は保持。
- build成果物にWatch/MyMusicWatch.app（maruyama.MyMusic.watchkitapp）を確認。Cometの導入済み一覧にもMyMusic 1.0 (1)を確認。ただしWatch本体に今回のbinaryが反映されたことまでは確認していない。今回はWatchコード／通信schema変更なし。
- Watch不具合候補: WatchSessionManagerのdidReceive fileはTask.detached内で一時fileを読む。Apple仕様ではdelegateから戻るとfileを削除するため、Artwork読取失敗の競合がある。https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate/session(_:didReceive:)
- 別候補: send失敗でisPhoneReachable=falseにするが、正常messageのapplyではtrueへ戻さない。WCSession reachability callbackが再発火しない場合、実際は通信可能でも操作ボタンがdisabledのままになる可能性。再現未確認。
- ユーザーの症状を質問済み。Watch修正はこの導入には混ぜていない。test追加実行なし、test端末作成・削除0。
