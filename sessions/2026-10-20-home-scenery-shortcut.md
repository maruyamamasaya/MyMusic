# ホームの車窓ショートカット

- Context Guard: MATCH。Git root確認済み。前タスクの未コミット変更を保持。
- HomeViewのテーマボタンの隣にtram.fillアイコンと44pt操作領域を追加。
- 再生中はqueue／位置を維持して車窓を開く。非再生中（一時停止も含む）は既存quickPlayTracksと代表曲先頭ポリシーを使用するstartImmediatePlaybackを共用し、再生要求後に車窓を開く。通常クイック再生の再生画面表示は維持。
- 読み込み中と非再生中で候補なしの場合は無効。空queueでは開かない。車窓を閉じるとホームへ戻る。動画未登録時の案内・音源の非同期再生エラーは既存処理に従う。再生成功まで待機する処理は追加しない。
- CURRENT／ARCHITECTURE更新。Service、永続化、project設定変更なし。
- HomeViewのSwift frontend parseとgit diff --check成功。標準generic iOS Simulator buildはwatchOS 26.5 must be installedで停止。型検証、実機の再生中／一時停止／停止／候補なし／動画未登録／復帰は未確認。
- XCTest・デプロイ未実施。test端末作成・削除0台。XCTestDevices容量計測対象のtest実行なし。
