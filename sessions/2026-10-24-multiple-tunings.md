# チューニング複数選択

- Context Guard: MATCH。Git rootは指定MyMusic repositoryと一致。
- ホームのタグを追加／解除式へ変更。選択ジャンルを和集合にし、最後の解除／全曲表示でリセットする。一覧にも同じ操作と全曲表示を用意。
- 設定中は単独名／N件選択中。全ジャンルを覆う組み合わせでも明示選択を保持。
- Storeに選択IDと保存／復元を追加。編集・削除・Import時の再適用と旧単独設定の引き継ぎに対応。設定画面からの単独適用は維持。
- プリセット交換JSON、再生queue、専用catalog、既存ジャンル除外規則は維持。HomeStereo変更なし。
- Store・ホーム2 View・LibraryGenreFilterTests・CURRENT・ARCHITECTURE・本記録を変更。既存のAGENTS.md変更と2026-10-23のsessionは保持。

## 検証と制約

- 指定iPhone 17e（EB3A49ED-6553-4D7E-B933-387951643EAB／iOS 26.5）の存在を確認。新規端末の作成なし。
- 指定destinationのDebug buildは既存VisualWorldInstallation.metalのコンパイルでMetal Toolchain不足により失敗。downloadや設定変更は実施していない。Swiftの型検証完了／BUILD SUCCEEDEDは未達。
- 変更Swift 4ファイルのswiftc -frontend -parse成功。git diff --check成功。専用lintなし。
- 合算・重複抑止・チェック・表示名・解除・リセット・再起動復元のXCTestを追加。build制約のためXCTest未実行。UI／実機確認・デプロイ未実施。
- XCTestDevicesはUUID folder 0件、合計12 KiB（既存.DS_Storeのみ）。test端末の作成0／削除0。既存Simulator内データ削除なし。

## 環境整備後の追検証

- ユーザー依頼によりMetal Toolchainを導入し、RootViewの式分割と承認済みprotocol隔離明示を実施。詳細は[環境記録](2026-10-24-xcode-validation-environment.md)。
- 指定SimulatorのiPhone／Watch build成功。LibraryGenreFilterTests 6件＋GenreDisplayPresetOrderingTests 1件成功。関連サービス回帰48件も成功。
- Device Hubで更新版を上書きinstall・launch（既存データ保持）。既存のジャンル未設定QA音源2曲と、新規の確認用A／Bプリセットを使用し、単独名→2件選択中→単独名→全曲表示、両タグのチェック、全曲表示ボタンのresetを確認。全ジャンルを覆う組み合わせでも選択チェックが維持された。異なる実ジャンルの曲集合はStore testで確認。画面操作中は再生していないため再生中キュー維持の実操作確認、Dynamic Type大、実機は未検証。
- 確認用A／BはSimulator内に残し、既存データを削除しない。

## ユーザー実機確認・コミット

- 2026-10-24、ユーザーがVesperaで複数選択・解除・全曲表示でのリセットを問題なしと確認。CURRENTとデプロイ記録へ反映。
- 明示依頼により複数選択、検証環境対応、テスト、関連文書をコミット。既存のAGENTS.md変更と2026-10-23-simulator-policy.mdは対象外。
- 記録更新のみのためbuild／test再実行なし。既存のbuild成功・55件成功を維持。git diff --check確認。test端末の作成0／削除0、XCTestDevices合計12 KiB。
