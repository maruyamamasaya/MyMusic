# チューニング切り替え後のホーム引き直し

- Context Guard: MATCH。Git rootはMyMusic repositoryと一致。
- LibraryStoreはチューニング／全曲表示filterの最新requestだけについて、snapshot反映時に完了ID・名称を公開する。
- HomeViewは完了を検知してseedを更新し、絞り込み済みの曲から代表曲・画像とMIXを引き直す。キャンセルされたホーム更新のpending通知は次の成功へ引き継ぐ。
- 即時の「設定しました」アラートを廃止。ホームsnapshot反映後に「○○に切り替えました」を2秒表示する。
- 保存形式・再生queueは変更しない。既存の別作業の変更を保持した。

## 検証

- generic iOS／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。
- 既存iPhone 17 Simulator 1台、並列無効でLibraryGenreFilterTests 5件成功。連続preset切り替えの最後だけが通知されること、完了前のID維持、全曲表示の完了と曲集合を既存テストに追加。
- git diff --check成功。専用lint設定なし。
- XCTestDevices: 開始前UUID folder 0件・0 bytes、終了後0件・0 bytes。新規作成0、削除0。Simulatorの新規作成なし。
- 実機での通知表示・操作感は未確認。デプロイ未実施。

## コミット前レビュー

- 完了待ちのチューニング更新と60秒の画像rotationが並走しないよう、pending通知があるrotationは通常のsnapshot taskとして既存更新をcancelする経路へ統一。古いsnapshotによる完了通知の重複を防ぐ。
- 既存のLibraryGenreFilterTests 5件成功記録を確認。今回の修正はViewのtask振分けのみ。
- レビュー修正後のgeneric iPhone／Watch Simulator Debug build: BUILD SUCCEEDED。git diff --check成功。今回はXCTest再実行なし、test端末の作成・削除0台。
