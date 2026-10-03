# TestFlight 外部テスト準備

- ユーザー依頼: 家族・友人へ送れる外部テストのパブリックリンクを作成する。
- App Store Connect にアプリが存在しなかったため、ユーザー承認済みの名前 `MyMusic Local Player` で登録。Apple ID: `6818121580`、Bundle ID: `maruyama.MyMusic`、日本語、SKU: `MyMusic-iOS`。
- `MyMusic` は名前の重複により登録不可だった。端末内のアプリ名、Bundle ID、Team、署名設定は変更していない。
- 既存 MyMusic Archive がなかったため、現在のコードから generic iOS / Release Archive を作成。`ARCHIVE SUCCEEDED`。成果物: `/private/tmp/MyMusic-TestFlight-20261001.xcarchive`。
- Xcode Organizer の App Store Connect 配布で `1.0 (1)` のアップロード成功を確認（2026-10-01 20:32 JST）。アップロード直後の Web UI はまだ「ビルドなし」で、Apple 側の処理・表示反映は未確認。
- Beta 審査のフィードバック用メール、審査連絡先メール・電話番号をユーザーへ質問済み。未回答のため審査提出はしていない。
- ビルドの反映を確認。暗号化質問を既存実装（Apple CryptoKitのhash利用、独自暗号化実装なし）に基づいて回答し、ビルド1は「提出準備完了」になった。
- Web UIには内部テストのみ表示され、「グループを作成」は内部グループ作成画面へ遷移する。内部グループ `Development` 作成準備の操作が自動承認レビューで拒否された（外部リンク依頼の範囲外の内部配布・将来ビルド自動配信との判断）。内部グループは未作成。自動配信checkboxは既定ONで、意図はOFFにすることだった。
- 外部テストグループとパブリックリンクは未作成。次回はユーザーの内部グループ作成承認と連絡先回答を受け、必要情報入力、外部グループ作成、Beta 審査提出を進める。
- Archive 時に `MusicHistoryView.swift:325` の既存 async/await warning が出た。今回の配布作業ではソース変更していない。
- XCTest は実行していない。test 端末の作成・削除は0台。
