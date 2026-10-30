# 再生中の音声出力先表示（2026-10-29）

- Context Guard: MATCH。Git rootがMyMusic repositoryと一致することを確認。
- 通常・作業用・ハイレゾの再生中画面左上に共通PlaybackOutputLabelを追加。
- speaker.wave.2.fillとcaption2の出力先名を最大120ptで表示。長い名前は末尾省略、VoiceOverは名前全体を読む。Unknown／空文字は非表示。
- PlayerStore.audioInformation.outputName／HiResDirectOutputProbeStore.snapshot.outputNameの既存通知・更新を使用。アイコンは共通のスピーカー記号。接続機種ごとの画像判定は追加しない。
- 通常再生のアート画面では既存palette操作を維持し出力ラベルは表示しない。
- Viewのみの変更で、Service／Store責務、音声出力設定、永続化、データ契約に変更なし。ARCHITECTURE.mdの更新不要。
- 既存の未コミット変更を保持。

## 検証

- 指定iPhone 17e（EB3A49ED-6553-4D7E-B933-387951643EAB）の存在・利用可能状態を確認。
- 標準のDebug Simulator build（CODE_SIGNING_ALLOWED=NO）: BUILD SUCCEEDED。git diff --check成功。
- 表示のみの変更のためtestは未実行。test端末作成0台・削除0台、XCTestDevicesの操作なし。
- 実画面の外観・Bluetooth／AirPlayの実機切替は未確認。実機へのデプロイなし。

## Vesperaデプロイ

- ユーザーの明示依頼でgit status確認後、check-iphone.sh成功 → deploy-iphone.sh実行。既存未コミット変更を保持。
- Project: MyMusic.xcodeproj、scheme／product: MyMusic、configuration: Debug、Bundle ID: maruyama.MyMusic。
- Vespera: iPhone 17e、UDID 00008150-000C54280E33401C、paired／Developer Mode enabled。
- Build／Install／Launchすべて成功。実機表示・出力先切替追従はユーザー確認待ち。
- アプリ・署名設定の追加変更なし。test未実行、test端末作成0・削除0、XCTestDevices操作なし。
