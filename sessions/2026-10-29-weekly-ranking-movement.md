# Weeklyの前週順位変動

- Context MATCH。Git root確認、CURRENT／ARCHITECTUREと既存ランキングService／Store／View／テストを調査。既存の音声出力方式等の別変更は保持。
- 各Weekly順位カードへ↑N／↓N／→／NEWを表示。記号と色の両方を使い、VoiceOverにも変動説明を追加。
- 総合／回数／時間ごとに対象週と前週のtop100順位をartist IDで比較。NEWは前週100位圏外または対象データなしであり、初再生の意味ではない。
- 今週は先週全体と、先週は先々週と比較。過去画面は増やさず、比較用に直前週を集計。現在のGood／favoriteを両週に使う点と、今週途中経過との比較を画面で説明。
- Storeの同一入力snapshotからbackgroundで両週を集計し、世代／cancelチェック後にページと比較結果を一緒に公開。方式切替時の再集計なし。
- Serviceに変動算出を追加。永続化／JSON／HomeStereo／音声処理の変更なし。
- CURRENT／ARCHITECTURE更新。

## 検証

- 指定iPhone 17e Simulator destinationでBUILD SUCCEEDED。
- 同UDID、並列無効でArtistRankingTests 8件成功。上昇／下降／同順位／NEW／空配列、Storeの週比較と全期間時の差分解除を追加検証。
- git diff --check成功。専用lintなし。
- XCTestDevices開始前／終了後ともUUIDフォルダなし、合計12K。test端末作成／削除0台、データ削除なし。
- 実表示／実機は未確認、今回変更は未デプロイ。
