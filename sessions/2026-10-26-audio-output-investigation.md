# 同時出力の調査（未解決）

- ユーザー報告: 出力選択でL soundbarだけにチェックがある状態でもMacと同時に鳴り、MyMusicの一時停止で両方停止。ヘッドフォン使用時にも同様の報告あり。画像のL soundbarはBluetoothアイコン付き。
- 通常AudioPlayerServiceは単一AVAudioEngine／playerNodeとplayback categoryを使用し、独自の複数出力・speaker overrideは見つからない。通常／Hi-ResはAppのbeforePlaybackで相互停止する。車窓AVPlayerはvideo-only compositionかつmute。コード調査だけで不具合なしとは断定しない。
- ユーザーがiPhoneミラーリングの使用を確認し、終了を依頼。UIの終了メニューで終了し、アプリ一覧でcom.apple.ScreenContinuityのisRunning=falseを確認。
- Apple公式 https://support.apple.com/en-us/120421 はミラーリング中のiPhone音声がMacで鳴ると説明。ただし今回の同時出力の原因と確定していない。終了後の実機再生結果を待つ。
- Macのprocess／audio device取得は環境制約で情報を取得できず。アプリコード・設定・署名の変更と実機deployは行っていない。
- build／XCTestは未実行。テスト端末の作成・削除は0台。XCTestDevicesの操作なし、残容量は未計測。
