# 再生中のいいね／Good保存負荷改善

## 背景・変更

Context Guard MATCH。MyMusic Git rootとcleanな開始状態を確認。CURRENT、ARCHITECTURE、ADR-0001、評価Store／保存Service／Home／Watchの更新経路を確認した。実機15,000曲で評価操作が遅いという報告を受け、タップごとの全件配列化と保存Taskの累積を改善。

TrackPreferenceStoreは単一保存Taskとrevisionで最新状態を保存する。保存中の追加操作は中間状態を列に積まず、次の保存へまとめる。配列化をMainActor外へ移し、Serviceのpretty print／key sortを廃止。状態の即時反映、schema v2、atomic write、読戻し検証、保存エラー表示、backup完了待機を維持。CURRENTとARCHITECTUREを更新。

## 検証

- generic iOS Simulator Debug build: BUILD SUCCEEDED（iPhone／Watch）。
- 既存iPhone 17e Simulator、並列無効・worker 1でTrackPreferencePersistenceTests 6件成功、失敗0。
- 15,000件の設定を読み込み、初回保存を保留してGood 5回といいね解除を行うテストを追加。即時状態と、保存完了後の最新状態・件数・保存2回を確認。
- 既存の移行／再読込／import／保存失敗テストも成功。既存testのyield回数依存待機はStoreの完了待機へ変更。
- git diff --check成功。専用lint設定なし。
- XCTestDevices開始／終了とも12 KB、UUID folder新規0、削除0。DerivedData削除なし。

## 未確認・制約

実機の体感・時間計測は未実施。全件JSON保存、Dictionaryのcopy-on-write、Homeや検索の評価変更に伴う再計算は残る。今回のテスト時間はUI応答性能の計測ではない。操作直後の強制終了で未完了保存が失われ得る既存の非同期保存特性は残る。

## 実機デプロイ・リモート保存

2026-10-12、ユーザー依頼でcheck-iphone.sh成功後にdeploy-iphone.shを実行。MyMusic.xcodeproj／MyMusic scheme／Product MyMusic／maruyama.MyMusic、Vespera（UDID 00008150-000C54280E33401C）へ未コミット変更を含むDebug build・install・launchが成功。署名・識別子・アプリ実装は変更しない。追加テストなし、test端末の作成・削除0。

2026-10-13、ユーザー依頼で変更と検証記録を確認し、上記デプロイ結果を文書へ反映してコミット・プッシュする。既に成功したテスト・buildの再実行は行わない。
