# アンビエントを聴く Beta

- Context Guard: MATCH。Git root確認、既存変更を保持。
- 発掘する音楽の末尾（ピアノの右）にアンビエントを聴くを追加。候補曲Artworkを使用し画像生成なし。
- AmbientSelectionPolicyでfinite・0...1内かつambient >= 0.5を採用。ピアノ同様の暫定cutoffであり、校正済み確率やジャンル判定の保証ではない。
- PlaybackHistoryStore.ambientPlayTracksはチューニング済み曲と通常shuffle適格性を維持し、均等ランダム再生。未解析・条件外へfallbackしない。
- snapshotのArtwork／代表曲と実再生に同条件。古い代表曲は現在候補で再検証。0曲は再生を変更せず案内。
- 詳細destinationにも同じ選曲条件。永続化・解析model・音声処理・署名変更なし。
- 実画面・実ライブラリでの選曲体感は未確認、実機未反映。

## 検証

- 指定既存iPhone 17e Simulator 1台を再利用し並列test無効。
- cutoff境界・欠落・不正値・入力範囲優先・声あり許可・重複除外・空候補をテスト。

- 関連19テスト成功（Ambient 2・Piano 2・HomeCategory 9・HomeRepresentative 6）。
- 指定destinationのDebug build成功（BUILD SUCCEEDED）、git diff --check成功。専用lint設定なし。
- テスト端末作成0・削除0。XCTestDevicesのUUID folderは開始前／終了後とも0件、残存12 KiB。削除なし。
- ログ: /tmp/mymusic-ambient-test.log、/tmp/mymusic-ambient-build.log。
