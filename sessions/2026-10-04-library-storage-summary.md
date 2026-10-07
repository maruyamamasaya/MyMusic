# ライブラリ登録音源の容量表示

- LibraryStorageSummaryを追加し、全登録Trackの曲数・既知容量・不明件数を集計。LibraryStoreの統合library更新時だけ再計算する。
- LibraryViewに登録済み音源／合計容量を表示。不明曲がある場合は確認済み容量と不明件数を表示。通常・作業用・ハイレゾ・非表示ジャンルを含み、iCloud未ダウンロード音源の論理容量とiPhone実使用容量の違いを説明する。
- 保存形式・Track Identity・再生・同期経路の変更なし。既存の未コミット変更は保持。
- generic iPhone／埋め込みWatch Simulator Debug build: BUILD SUCCEEDED。初回sandbox buildはキャッシュ権限不足で失敗し、権限付きで成功。
- 容量集計のXCTestを3件追加。今回はSimulator testを実行せず、同じ集計ソースをswiftcで単独実行し空値／未知値・負値／overflowの3件を確認（成功、1,250,000,000 bytes → 1.25 GB）。git diff --check成功。
- XCTestDevicesのtest端末作成・削除は0台（test未実施）。実機UI／デプロイ未検証。
