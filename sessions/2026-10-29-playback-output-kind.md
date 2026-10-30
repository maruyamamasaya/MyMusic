# 再生中の接続方式・機器名（2026-10-29）

- Context Guard MATCH、Git root一致。CURRENT／ARCHITECTURE／ADR-0001と既存出力通知を確認。既存のランキング等の未コミット変更は保持。
- AudioInformationへoptional outputPortType、AudioPlayerServiceの出力eventとAudioInformationService通知へportType.rawValueを追加。PlayerStoreで名前・sample rateとともに更新し、metadata取得後の最新出力保持にも追加。
- PlaybackOutputLabelを接続方式・機器名の2段へ変更。Bluetooth、AirPlay、有線ヘッドホン、USB、内蔵スピーカー、受話口、車載、ライン、ディスプレイ出力を区別。Bluetoothの機器形状は推測しない。
- タップするとpopoverで接続方式と機器名全文を表示。出力切替機能なし。HiResは既存snapshotのportTypeを使用。
- 再生の出力設定・永続化・JSON変更なし。通常アート画面のpalette優先は維持。

## 検証

- 指定iPhone 17e Simulator宛Debug build: BUILD SUCCEEDED。
- 表示および既存通知の付随情報追加のみのためtest未実行。test端末作成0・削除0、XCTestDevices操作なし。
- 実機未反映。各接続機器での表示・popover配置・Dynamic Typeの実表示は未確認。

## Vesperaデプロイ

- 明示依頼に基づきgit status確認、check-iphone.sh成功後にdeploy-iphone.sh実行。未コミット変更を保持。
- Project: MyMusic.xcodeproj、scheme／product: MyMusic、Debug、Bundle ID: maruyama.MyMusic。
- Vespera（iPhone 17e）、UDID 00008150-000C54280E33401C。paired／Developer Mode enabledを確認。
- Build／Install／Launchすべて成功。実機での外観・接続別表示は確認待ち。
- 追加のアプリコード・構成変更なし。test未実行、test端末作成0・削除0、XCTestDevices操作なし。
